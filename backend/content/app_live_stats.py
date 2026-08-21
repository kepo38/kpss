"""Panel uygulama canlılık / kurulum / premium özet metrikleri."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta

from django.db.models import Q
from django.utils import timezone

from .models import AppUser, DeviceToken


ACTIVE_WINDOW = timedelta(minutes=15)
DAY_WINDOW = timedelta(hours=24)


@dataclass(frozen=True)
class AppLiveStats:
    install_devices: int
    total_users: int
    account_users: int
    guest_users: int
    active_now: int
    active_24h: int
    premium_users: int
    premium_yearly: int
    premium_monthly_or_other: int


def collect_app_live_stats() -> AppLiveStats:
    now = timezone.now()
    active_since = now - ACTIVE_WINDOW
    day_since = now - DAY_WINDOW

    install_devices = DeviceToken.objects.filter(is_active=True).count()
    total_users = AppUser.objects.filter(is_active=True).count()
    account_users = AppUser.objects.filter(
        is_active=True, is_anonymous=False
    ).count()
    guest_users = AppUser.objects.filter(
        is_active=True, is_anonymous=True
    ).count()

    active_user_ids = set(
        AppUser.objects.filter(
            is_active=True,
            last_active_at__gte=active_since,
        ).values_list("id", flat=True)
    )
    device_user_ids = set(
        DeviceToken.objects.filter(
            is_active=True,
            last_seen_at__gte=active_since,
            user_id__isnull=False,
        ).values_list("user_id", flat=True)
    )
    orphan_active_devices = DeviceToken.objects.filter(
        is_active=True,
        last_seen_at__gte=active_since,
        user__isnull=True,
    ).count()
    active_now = len(active_user_ids | device_user_ids) + orphan_active_devices

    active_24h = AppUser.objects.filter(
        is_active=True,
        last_active_at__gte=day_since,
    ).count()

    premium_qs = AppUser.objects.filter(is_active=True, is_premium=True).filter(
        Q(premium_expires_at__isnull=True) | Q(premium_expires_at__gt=now)
    )
    premium_users = premium_qs.count()
    premium_yearly = 0
    for user in premium_qs.only(
        "premium_product_id", "premium_grant_note", "is_premium", "premium_expires_at"
    ):
        if user.is_yearly_premium:
            premium_yearly += 1
    premium_monthly_or_other = max(0, premium_users - premium_yearly)

    return AppLiveStats(
        install_devices=install_devices,
        total_users=total_users,
        account_users=account_users,
        guest_users=guest_users,
        active_now=active_now,
        active_24h=active_24h,
        premium_users=premium_users,
        premium_yearly=premium_yearly,
        premium_monthly_or_other=premium_monthly_or_other,
    )
