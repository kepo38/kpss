"""Promosyon kodu doğrulama ve kullanım."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from django.db import transaction
from django.utils import timezone

from .models import AppUser, PromoCode, PromoCodeRedemption, normalize_promo_code


class PromoError(Exception):
    def __init__(self, message: str, *, status: int = 400):
        super().__init__(message)
        self.message = message
        self.status = status


@dataclass(frozen=True)
class PromoRedeemResult:
    promo_code: PromoCode
    premium_expires_at: datetime
    message: str


def redeem_promo_code(*, user: AppUser, raw_code: str) -> PromoRedeemResult:
    code = normalize_promo_code(raw_code)
    if not code:
        raise PromoError("Promosyon kodu gerekli.")

    with transaction.atomic():
        promo = (
            PromoCode.objects.select_for_update()
            .filter(code=code)
            .first()
        )
        if promo is None:
            raise PromoError("Geçersiz promosyon kodu.", status=404)

        if not promo.is_within_schedule():
            raise PromoError("Bu promosyon kodunun süresi dolmuş veya henüz başlamamış.")

        if PromoCodeRedemption.objects.filter(promo_code=promo, user=user).exists():
            raise PromoError("Bu promosyon kodunu zaten kullandınız.")

        used = promo.redemption_count
        if used >= promo.max_redemptions:
            raise PromoError("Bu promosyon kodunun kullanım kotası dolmuş.")

        now = timezone.now()
        base = now
        if user.premium_active and user.premium_expires_at is not None:
            base = max(now, user.premium_expires_at)

        expires_at = base + timedelta(days=promo.premium_duration_days)
        note = f"Promo: {promo.code}"
        if promo.title:
            note = f"Promo: {promo.code} ({promo.title})"

        user.grant_free_premium(expires_at=expires_at, note=note[:255])
        PromoCodeRedemption.objects.create(
            promo_code=promo,
            user=user,
            premium_expires_at=expires_at,
        )
        PromoCode.objects.filter(pk=promo.pk).update(updated_at=now)

    days = promo.premium_duration_days
    message = f"Premium {days} gün tanımlandı."
    return PromoRedeemResult(
        promo_code=promo,
        premium_expires_at=expires_at,
        message=message,
    )
