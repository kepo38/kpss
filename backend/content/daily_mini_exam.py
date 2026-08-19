"""Günün ücretsiz mini denemesi — pencere, soru seçimi, sıralama."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
from typing import Iterable

from django.utils import timezone

from .models import DailyMiniExam, Question

QUESTION_COUNT = 20
PER_POOL = 5
OPENS_HOUR = 6
TURKCE_TOPIC_SLUGS = ("turkce_anlam", "turkce_dilbilgisi")
VALID_KPSS_TYPES = ("lisans", "onLisans", "ortaogretim")
SUBJECT_POOLS = ("tarih", "cografya", "vatandaslik")
DEMO_EMAIL_PREFIX = "demo.mini"
DEMO_GOOGLE_SUB_PREFIX = "demo-mini-leader-"


def is_demo_mini_user(user) -> bool:
    """seed_daily_mini_demo kayıtları — canlı kürsüde gösterilmez."""
    if user is None:
        return False
    email = (getattr(user, "email", "") or "").strip().lower()
    google_sub = (getattr(user, "google_sub", "") or "").strip()
    return email.startswith(DEMO_EMAIL_PREFIX) or google_sub.startswith(
        DEMO_GOOGLE_SUB_PREFIX
    )


def attempts_for_leaderboard(exam_date: date, kpss_type: str):
    from .models import DailyMiniExamAttempt

    return (
        DailyMiniExamAttempt.objects.filter(
            exam_date=exam_date,
            kpss_type=kpss_type,
        )
        .exclude(user__email__startswith=DEMO_EMAIL_PREFIX)
        .exclude(user__google_sub__startswith=DEMO_GOOGLE_SUB_PREFIX)
        .select_related("user")
    )


def istanbul_now() -> datetime:
    return timezone.localtime()


def exam_date_for(now: datetime | None = None) -> date:
    return (now or istanbul_now()).date()


def window_bounds(now: datetime | None = None) -> tuple[datetime, datetime, datetime]:
    """(şimdi, bugün 06:00, gece yarısı kapanış)."""
    current = now or istanbul_now()
    today = current.date()
    tz = current.tzinfo
    opens_at = datetime.combine(today, time(OPENS_HOUR, 0), tzinfo=tz)
    closes_at = datetime.combine(today + timedelta(days=1), time(0, 0), tzinfo=tz)
    return current, opens_at, closes_at


def is_exam_open(now: datetime | None = None) -> bool:
    current, opens_at, closes_at = window_bounds(now)
    return opens_at <= current < closes_at


def guest_login_required(user, exam_date: date | None = None) -> bool:
    """Misafir yalnızca kayıt gününde katılır; sonraki günlerde giriş zorunlu."""
    if user is None or not getattr(user, "is_anonymous", False):
        return False
    created = getattr(user, "created_at", None)
    if created is None:
        return False
    created_day = timezone.localtime(created).date()
    day = exam_date or exam_date_for()
    return day > created_day


def seconds_until_deadline(now: datetime | None = None) -> int:
    """Açıkken gece yarısına, kapalıyken 06:00'e kalan saniye."""
    current, opens_at, closes_at = window_bounds(now)
    target = closes_at if current >= opens_at else opens_at
    return max(0, int((target - current).total_seconds()))


def split_frosted_email(email: str) -> tuple[str, str]:
    """@ öncesinde ilk 3 harfi gösterir; kalanını @ işaretine kadar gizler."""
    value = (email or "").strip()
    if not value:
        return "", ""
    if "@" not in value:
        prefix = value[:3]
        masked = "•" * max(0, len(value) - len(prefix))
        return prefix, masked
    local, domain = value.split("@", 1)
    if len(local) <= 3:
        return local, f"@{domain}"
    return local[:3], f"•••@{domain}"


def _uint32_seed(exam_date: date, kpss_type: str) -> int:
    raw = f"{exam_date.isoformat()}|{kpss_type}|daily-mini-v1".encode()
    h = 2166136261
    for byte in raw:
        h ^= byte
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def lcg_shuffle(items: list[str], seed: int) -> list[str]:
    """Python/Dart ortak LCG Fisher-Yates — aynı seed aynı sıra."""
    arr = list(items)
    state = seed & 0xFFFFFFFF
    for i in range(len(arr) - 1, 0, -1):
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        j = state % (i + 1)
        arr[i], arr[j] = arr[j], arr[i]
    return arr


def _published_ids(*, subject_slug: str | None = None, topic_slugs: Iterable[str] | None = None) -> list[str]:
    qs = Question.objects.filter(is_published=True, topic__is_active=True)
    if subject_slug:
        qs = qs.filter(topic__subject__slug=subject_slug)
    if topic_slugs is not None:
        qs = qs.filter(topic__slug__in=list(topic_slugs))
    return list(qs.order_by("public_id").values_list("public_id", flat=True))


def pick_question_ids(exam_date: date, kpss_type: str) -> list[str]:
    seed = _uint32_seed(exam_date, kpss_type)
    selected: list[str] = []
    used: set[str] = set()

    pools: list[list[str]] = [
        _published_ids(subject_slug="tarih"),
        _published_ids(subject_slug="cografya"),
        _published_ids(subject_slug="vatandaslik"),
        _published_ids(topic_slugs=TURKCE_TOPIC_SLUGS),
    ]
    for pool in pools:
        unused = [qid for qid in pool if qid not in used]
        shuffled = lcg_shuffle(unused, seed)
        take = shuffled[:PER_POOL]
        selected.extend(take)
        used.update(take)

    if len(selected) < QUESTION_COUNT:
        leftovers = [
            qid
            for qid in _published_ids()
            if qid not in used
        ]
        extra = lcg_shuffle(leftovers, seed ^ 0xA5A5A5A5)[: QUESTION_COUNT - len(selected)]
        selected.extend(extra)

    return selected[:QUESTION_COUNT]


def get_or_create_today_exam(kpss_type: str, now: datetime | None = None) -> DailyMiniExam:
    exam_date = exam_date_for(now)
    exam, created = DailyMiniExam.objects.get_or_create(
        exam_date=exam_date,
        kpss_type=kpss_type,
        defaults={"question_ids": pick_question_ids(exam_date, kpss_type)},
    )
    if created:
        return exam
    if not exam.question_ids:
        exam.question_ids = pick_question_ids(exam_date, kpss_type)
        exam.save(update_fields=["question_ids"])
    return exam


def leaderboard_rows(exam_date: date, kpss_type: str, *, limit: int = 20) -> list[dict]:
    attempts = (
        attempts_for_leaderboard(exam_date, kpss_type)
        .order_by("-correct", "duration_seconds", "completed_at")[:limit]
    )
    rows = []
    for index, attempt in enumerate(attempts, start=1):
        prefix, rest = split_frosted_email(attempt.user.email)
        display = (attempt.user.display_name or "").strip()
        rows.append(
            {
                "rank": index,
                "userId": str(attempt.user_id),
                "displayName": display,
                "emailPrefix": prefix,
                "emailRest": rest,
                "correct": attempt.correct,
                "wrong": attempt.wrong,
                "blank": attempt.blank,
                "durationSeconds": attempt.duration_seconds,
            }
        )
    return rows


def rank_for_user(exam_date: date, kpss_type: str, user_id: int) -> tuple[int | None, int]:
    qs = attempts_for_leaderboard(exam_date, kpss_type).order_by(
        "-correct", "duration_seconds", "completed_at"
    )
    total = qs.count()
    for index, attempt in enumerate(qs.only("user_id"), start=1):
        if attempt.user_id == user_id:
            return index, total
    return None, total
