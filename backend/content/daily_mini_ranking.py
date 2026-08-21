"""Haftalık / aylık mini deneme sıralaması ve premium ödülleri."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Literal

from django.db import transaction
from django.db.models import Count, Sum
from django.utils import timezone

from .daily_mini_exam import (
    VALID_KPSS_TYPES,
    is_demo_mini_user,
    split_frosted_email,
)
from .models import AppUser, DailyMiniExamAttempt, DailyMiniRankingWinner

PeriodKind = Literal["weekly", "monthly"]

REWARD_DAYS = {1: 3, 2: 2, 3: 1}


def get_ranking_campaign():
    from .models import DailyMiniRankingCampaign

    obj, _ = DailyMiniRankingCampaign.objects.get_or_create(pk=1)
    return obj


def istanbul_today() -> date:
    return timezone.localdate()


def period_bounds(kind: PeriodKind, *, reference: date | None = None) -> tuple[date, date]:
    """Hafta: Pazartesi–Pazar; ay: takvim ayı (Europe/Istanbul günü)."""
    day = reference or istanbul_today()
    if kind == "weekly":
        start = day - timedelta(days=day.weekday())
        end = start + timedelta(days=6)
        return start, end
    start = day.replace(day=1)
    if start.month == 12:
        next_month = start.replace(year=start.year + 1, month=1, day=1)
    else:
        next_month = start.replace(month=start.month + 1, day=1)
    end = next_month - timedelta(days=1)
    return start, end


def previous_period_bounds(kind: PeriodKind, *, reference: date | None = None) -> tuple[date, date]:
    day = reference or istanbul_today()
    if kind == "weekly":
        this_start, _ = period_bounds("weekly", reference=day)
        prev_end = this_start - timedelta(days=1)
        return period_bounds("weekly", reference=prev_end)
    first = day.replace(day=1)
    prev_end = first - timedelta(days=1)
    return period_bounds("monthly", reference=prev_end)


def _qualifying_attempts(start: date, end: date, kpss_type: str):
    return (
        DailyMiniExamAttempt.objects.filter(
            exam_date__gte=start,
            exam_date__lte=end,
            kpss_type=kpss_type,
        )
        .exclude(correct=0, wrong=0)
        .exclude(user__email__startswith="demo.mini")
        .exclude(user__google_sub__startswith="demo-mini-leader-")
        .select_related("user")
    )


def aggregate_leaderboard(
    kind: PeriodKind,
    kpss_type: str,
    *,
    start: date | None = None,
    end: date | None = None,
    limit: int = 50,
) -> list[dict]:
    if start is None or end is None:
        start, end = period_bounds(kind)
    rows = (
        _qualifying_attempts(start, end, kpss_type)
        .values("user_id", "user__email", "user__display_name")
        .annotate(
            total_correct=Sum("correct"),
            total_duration=Sum("duration_seconds"),
            days_played=Count("id"),
        )
        .order_by("-total_correct", "total_duration", "user_id")[:limit]
    )
    out: list[dict] = []
    for index, row in enumerate(rows, start=1):
        prefix, rest = split_frosted_email(row["user__email"] or "")
        display = (row["user__display_name"] or "").strip()
        out.append(
            {
                "rank": index,
                "userId": str(row["user_id"]),
                "displayName": display,
                "emailPrefix": prefix,
                "emailRest": rest,
                "totalCorrect": int(row["total_correct"] or 0),
                "totalDurationSeconds": int(row["total_duration"] or 0),
                "daysPlayed": int(row["days_played"] or 0),
            }
        )
    return out


def rank_for_user_period(
    kind: PeriodKind,
    kpss_type: str,
    user_id: int,
    *,
    start: date | None = None,
    end: date | None = None,
) -> tuple[int | None, int, int, int]:
    if start is None or end is None:
        start, end = period_bounds(kind)
    agg = (
        _qualifying_attempts(start, end, kpss_type)
        .values("user_id")
        .annotate(
            total_correct=Sum("correct"),
            total_duration=Sum("duration_seconds"),
        )
        .order_by("-total_correct", "total_duration", "user_id")
    )
    total = agg.count()
    my_correct = 0
    my_duration = 0
    for index, row in enumerate(agg, start=1):
        if row["user_id"] == user_id:
            my_correct = int(row["total_correct"] or 0)
            my_duration = int(row["total_duration"] or 0)
            return index, total, my_correct, my_duration
    return None, total, my_correct, my_duration


def participant_count(start: date, end: date, kpss_type: str) -> int:
    return (
        _qualifying_attempts(start, end, kpss_type)
        .values("user_id")
        .distinct()
        .count()
    )


def grant_premium_days(user: AppUser, days: int, note: str) -> datetime:
    now = timezone.now()
    base = now
    if user.premium_active and user.premium_expires_at is not None:
        base = max(now, user.premium_expires_at)
    expires_at = base + timedelta(days=days)
    user.grant_free_premium(expires_at=expires_at, note=note[:255])
    return expires_at


def _period_already_finalized(kind: PeriodKind, start: date, kpss_type: str) -> bool:
    return DailyMiniRankingWinner.objects.filter(
        period_kind=kind,
        period_start=start,
        kpss_type=kpss_type,
    ).exists()


@transaction.atomic
def finalize_period(
    kind: PeriodKind,
    kpss_type: str,
    *,
    start: date | None = None,
    end: date | None = None,
    send_push: bool = True,
) -> list[DailyMiniRankingWinner]:
    if kpss_type not in VALID_KPSS_TYPES:
        raise ValueError("Geçersiz kpss_type")
    if start is None or end is None:
        start, end = previous_period_bounds(kind)

    if end >= istanbul_today() and kind == "weekly":
        # Henüz bitmemiş haftayı finalize etme
        start, end = previous_period_bounds(kind)
    if end >= istanbul_today() and kind == "monthly":
        start, end = previous_period_bounds(kind)

    if _period_already_finalized(kind, start, kpss_type):
        return []

    campaign = get_ranking_campaign()
    if kind == "weekly" and not campaign.weekly_enabled:
        return []
    if kind == "monthly" and not campaign.monthly_enabled:
        return []

    board = aggregate_leaderboard(kind, kpss_type, start=start, end=end, limit=3)
    created: list[DailyMiniRankingWinner] = []
    from .models import UserMessage
    from .push import send_user_message_push

    for row in board:
        rank = row["rank"]
        days = REWARD_DAYS.get(rank)
        if not days:
            continue
        try:
            user = AppUser.objects.get(pk=int(row["userId"]))
        except AppUser.DoesNotExist:
            continue
        if is_demo_mini_user(user):
            continue

        period_label = "Haftalık" if kind == "weekly" else "Aylık"
        note = f"{period_label} mini deneme #{rank}. — {days} gün premium"
        expires = grant_premium_days(user, days, note)

        title = f"🎉 {period_label} sıralama ödülü"
        body = (
            f"Tebrikler! {period_label} mini denemede {rank}. oldunuz. "
            f"{days} gün Premium hesabınıza tanımlandı."
        )
        msg = UserMessage.objects.create(user=user, title=title, body=body)
        if send_push:
            send_user_message_push(msg)

        winner = DailyMiniRankingWinner.objects.create(
            period_kind=kind,
            period_start=start,
            period_end=end,
            kpss_type=kpss_type,
            rank=rank,
            user=user,
            total_correct=row["totalCorrect"],
            total_duration_seconds=row["totalDurationSeconds"],
            premium_days=days,
            display_name=(user.display_name or "").strip(),
            email_prefix=row["emailPrefix"],
            email_rest=row["emailRest"],
        )
        created.append(winner)
    return created


def reward_history(kpss_type: str, *, limit: int = 24) -> list[dict]:
    winners = (
        DailyMiniRankingWinner.objects.filter(kpss_type=kpss_type)
        .select_related("user")
        .order_by("-period_start", "rank")[: limit * 3]
    )
    grouped: dict[tuple[str, date, date], list[dict]] = {}
    for w in winners:
        key = (w.period_kind, w.period_start, w.period_end)
        grouped.setdefault(key, []).append(
            {
                "rank": w.rank,
                "displayName": w.display_name or w.email_prefix,
                "emailPrefix": w.email_prefix,
                "emailRest": w.email_rest,
                "totalCorrect": w.total_correct,
                "totalDurationSeconds": w.total_duration_seconds,
                "premiumDays": w.premium_days,
            }
        )
    periods: list[dict] = []
    for (kind, start, end), rows in sorted(grouped.items(), key=lambda x: x[0][1], reverse=True):
        periods.append(
            {
                "periodKind": kind,
                "periodStart": start.isoformat(),
                "periodEnd": end.isoformat(),
                "winners": sorted(rows, key=lambda r: r["rank"]),
            }
        )
        if len(periods) >= limit:
            break
    return periods


def period_ranking_payload(
    kind: PeriodKind,
    kpss_type: str,
    user_id: int | None,
) -> dict:
    campaign = get_ranking_campaign()
    start, end = period_bounds(kind)
    board = aggregate_leaderboard(kind, kpss_type, start=start, end=end)
    my_rank = None
    my_correct = 0
    my_duration = 0
    if user_id is not None:
        my_rank, _, my_correct, my_duration = rank_for_user_period(
            kind, kpss_type, user_id, start=start, end=end
        )
    enabled = campaign.weekly_enabled if kind == "weekly" else campaign.monthly_enabled
    return {
        "period": kind,
        "periodStart": start.isoformat(),
        "periodEnd": end.isoformat(),
        "participantCount": participant_count(start, end, kpss_type),
        "myRank": my_rank,
        "myTotalCorrect": my_correct,
        "myTotalDurationSeconds": my_duration,
        "leaderboard": board,
        "rewardsVisible": campaign.rewards_visible,
        "rewardsEnabled": enabled and campaign.rewards_visible,
        "rewardDays": {str(k): v for k, v in REWARD_DAYS.items()},
    }
