"""Google / Firebase kimlik doğrulama — mobil giriş."""

from __future__ import annotations

import base64
import json
import logging
import secrets
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import AppUser
from .push import _ensure_firebase_app, firebase_ready

logger = logging.getLogger(__name__)

GUEST_EMAIL_DOMAIN = "guest.hedefkamu.app"
GUEST_DISPLAY_NAME = "Misafir"

_FIREBASE_ISS_MARKER = "securetoken.google.com"
_FIREBASE_CONFIG_MSG = (
    "Sunucu Firebase yapılandırması eksik. "
    "Yönetici FIREBASE_CREDENTIALS (servis hesabı JSON) eklemeli."
)


class AuthError(Exception):
    def __init__(self, message: str, *, status: int = 401):
        super().__init__(message)
        self.message = message
        self.status = status


def _jwt_iss(token: str) -> str:
    """İmza doğrulamadan JWT iss alanını okur (yalnızca yönlendirme için)."""
    try:
        parts = (token or "").split(".")
        if len(parts) < 2:
            return ""
        payload = parts[1]
        pad = "=" * (-len(payload) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload + pad))
        if isinstance(data, dict):
            return str(data.get("iss") or "")
    except Exception:  # noqa: BLE001
        return ""
    return ""


def _is_firebase_id_token(token: str) -> bool:
    return _FIREBASE_ISS_MARKER in _jwt_iss(token)


def new_api_token() -> str:
    return secrets.token_urlsafe(32)


def guest_email(sub: str) -> str:
    safe = "".join(ch for ch in sub if ch.isalnum())[:48] or "user"
    return f"anon+{safe}@{GUEST_EMAIL_DOMAIN}"


def is_guest_email(email: str) -> bool:
    return (email or "").endswith(f"@{GUEST_EMAIL_DOMAIN}")


def is_guest_display_name(name: str) -> bool:
    return (name or "").strip().casefold() == GUEST_DISPLAY_NAME.casefold()


def resolve_display_name(
    *,
    name: str,
    email: str,
    current: str = "",
) -> str:
    """Kalıcı hesaba geçişte Misafir yer tutucusunu gerçek adla değiştir."""
    cleaned_name = (name or "").strip()
    if cleaned_name:
        return cleaned_name
    current = (current or "").strip()
    if current and not is_guest_display_name(current):
        return current
    local = (email or "").split("@")[0].strip()
    if local and not is_guest_email(email):
        return local
    return current or GUEST_DISPLAY_NAME


def heal_guest_display_name(user: AppUser) -> bool:
    """Misafir adı kalmış kalıcı hesabı e-posta önekine çeker."""
    if user.is_anonymous or not is_guest_display_name(user.display_name):
        return False
    email = (user.email or "").strip()
    if not email or is_guest_email(email):
        return False
    user.display_name = email.split("@")[0]
    user.save(update_fields=["display_name", "updated_at"])
    return True


def verify_id_token(id_token: str) -> dict[str, Any]:
    """
    Firebase Auth ID token veya Google ID token doğrular.
    Dönen alanlar: sub, email, name, picture, is_anonymous
    """
    token = (id_token or "").strip()
    if not token:
        raise AuthError("Kimlik jetonu gerekli.")

    ready, ready_err = firebase_ready()
    looks_firebase = _is_firebase_id_token(token)

    if not ready and looks_firebase:
        # Firebase JWT ile gelindi ama servis hesabı yok — yanıltıcı
        # "Geçersiz Google oturumu" yerine açık yapılandırma hatası.
        raise AuthError(ready_err or _FIREBASE_CONFIG_MSG, status=503)

    if ready:
        try:
            _ensure_firebase_app()
            from firebase_admin import auth as fb_auth

            decoded = fb_auth.verify_id_token(token)
            firebase_meta = decoded.get("firebase") or {}
            provider = str(firebase_meta.get("sign_in_provider") or "")
            return {
                "sub": str(decoded.get("uid") or decoded.get("sub") or ""),
                "email": str(decoded.get("email") or ""),
                "name": str(decoded.get("name") or ""),
                "picture": str(decoded.get("picture") or ""),
                "is_anonymous": provider == "anonymous",
            }
        except AuthError:
            raise
        except Exception as exc:  # noqa: BLE001
            if looks_firebase:
                logger.info("Firebase token doğrulama başarısız: %s", exc)
                raise AuthError(
                    "Geçersiz veya süresi dolmuş oturum. Tekrar giriş yapın."
                ) from exc
            logger.info(
                "Firebase token doğrulama başarısız, Google deneniyor: %s", exc
            )

    claims = _verify_google_tokeninfo(token)
    claims["is_anonymous"] = False
    return claims


def verify_access_token(access_token: str) -> dict[str, Any]:
    """Google access token ile kullanıcı bilgisi (idToken yoksa)."""
    token = (access_token or "").strip()
    if not token:
        raise AuthError("Erişim jetonu gerekli.")

    req = urllib.request.Request(
        "https://www.googleapis.com/oauth2/v3/userinfo",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise AuthError("Geçersiz Google oturumu. Tekrar giriş yapın.") from exc
    except Exception as exc:  # noqa: BLE001
        raise AuthError("Kimlik doğrulama servisine ulaşılamadı.") from exc

    sub = str(data.get("sub") or "")
    email = str(data.get("email") or "")
    if not sub or not email:
        raise AuthError("Google hesabından e-posta alınamadı.")

    return {
        "sub": sub,
        "email": email,
        "name": str(data.get("name") or ""),
        "picture": str(data.get("picture") or ""),
        "is_anonymous": False,
    }


def resolve_google_claims(
    *,
    id_token: str = "",
    access_token: str = "",
) -> dict[str, Any]:
    """Önce id_token, yoksa access_token dene."""
    claims: dict[str, Any] | None = None
    if (id_token or "").strip():
        try:
            claims = verify_id_token(id_token)
        except AuthError:
            if not (access_token or "").strip():
                raise
            logger.info("id_token başarısız, access_token deneniyor")
    if claims is None:
        if (access_token or "").strip():
            claims = verify_access_token(access_token)
        else:
            raise AuthError("Kimlik jetonu gerekli.")

    if not claims.get("is_anonymous") and not (claims.get("name") or "").strip():
        token = (access_token or "").strip()
        if token:
            try:
                profile = verify_access_token(token)
                if (profile.get("name") or "").strip():
                    claims["name"] = profile["name"]
                if not (claims.get("email") or "").strip() and profile.get("email"):
                    claims["email"] = profile["email"]
                if not (claims.get("picture") or "").strip() and profile.get(
                    "picture"
                ):
                    claims["picture"] = profile["picture"]
            except AuthError:
                pass
    return claims


def _verify_google_tokeninfo(id_token: str) -> dict[str, Any]:
    url = "https://oauth2.googleapis.com/tokeninfo?" + urllib.parse.urlencode(
        {"id_token": id_token}
    )
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise AuthError("Geçersiz Google oturumu. Tekrar giriş yapın.") from exc
    except Exception as exc:  # noqa: BLE001
        raise AuthError("Kimlik doğrulama servisine ulaşılamadı.") from exc

    aud = str(data.get("aud") or "")
    allowed = getattr(settings, "GOOGLE_OAUTH_CLIENT_IDS", None) or []
    if allowed and aud not in allowed:
        raise AuthError("Bu uygulama için geçersiz Google istemcisi.")

    sub = str(data.get("sub") or "")
    email = str(data.get("email") or "")
    if not sub or not email:
        raise AuthError("Google hesabından e-posta alınamadı.")

    return {
        "sub": sub,
        "email": email,
        "name": str(data.get("name") or ""),
        "picture": str(data.get("picture") or ""),
    }


def upsert_firebase_user(
    claims: dict[str, Any],
    *,
    guest_sub: str = "",
) -> AppUser:
    """Firebase (anonim veya Google) oturumunu AppUser kaydına yazar."""
    sub = (claims.get("sub") or "").strip()
    if not sub:
        raise AuthError("Eksik hesap bilgisi.")

    is_anonymous = bool(claims.get("is_anonymous"))
    email = (claims.get("email") or "").strip().lower()
    name = (claims.get("name") or "").strip()
    picture = (claims.get("picture") or "").strip()[:512]
    now = timezone.now()

    user = AppUser.objects.filter(google_sub=sub).first()
    if user is not None:
        if not user.is_active:
            raise AuthError(
                "Hesabınız engellenmiş. Destek ile iletişime geçin.",
                status=403,
            )
        user.last_login_at = now
        user.api_token = new_api_token()
        if is_anonymous:
            user.save(
                update_fields=["last_login_at", "api_token", "updated_at"]
            )
            return user

        if email:
            user.email = email
        user.photo_url = picture or user.photo_url
        user.is_anonymous = False
        user.display_name = resolve_display_name(
            name=name,
            email=email or user.email,
            current=user.display_name,
        )
        user.save()
        purge_orphan_guest_after_merge(guest_sub=guest_sub, keep_user=user)
        return user

    if is_anonymous:
        return AppUser.objects.create(
            google_sub=sub,
            email=guest_email(sub),
            display_name="Misafir",
            photo_url="",
            is_anonymous=True,
            api_token=new_api_token(),
            last_login_at=now,
        )

    if not email:
        raise AuthError("Google hesabından e-posta alınamadı.")

    existing_email = AppUser.objects.filter(email=email).first()
    if existing_email is not None:
        if not existing_email.is_active:
            raise AuthError(
                "Hesabınız engellenmiş. Destek ile iletişime geçin.",
                status=403,
            )
        existing_email.google_sub = sub
        existing_email.email = email
        existing_email.photo_url = picture or existing_email.photo_url
        existing_email.is_anonymous = False
        existing_email.last_login_at = now
        existing_email.api_token = new_api_token()
        existing_email.display_name = resolve_display_name(
            name=name,
            email=email,
            current=existing_email.display_name,
        )
        existing_email.save()
        purge_orphan_guest_after_merge(guest_sub=guest_sub, keep_user=existing_email)
        return existing_email

    user = AppUser.objects.create(
        google_sub=sub,
        email=email,
        display_name=name or email.split("@")[0],
        photo_url=picture,
        is_anonymous=False,
        api_token=new_api_token(),
        last_login_at=now,
    )
    purge_orphan_guest_after_merge(guest_sub=guest_sub, keep_user=user)
    return user


def _merge_premium_fields(*, guest: AppUser, target: AppUser) -> None:
    """Misafir premium'u kalıcı hesaba taşır (hedef aktif değilse veya daha uzunsa)."""
    if not guest.premium_active:
        return
    if not target.premium_active:
        target.is_premium = guest.is_premium
        target.premium_expires_at = guest.premium_expires_at
        target.premium_granted_at = guest.premium_granted_at
        target.premium_grant_note = guest.premium_grant_note or target.premium_grant_note
        target.premium_product_id = guest.premium_product_id or target.premium_product_id
        target.save(
            update_fields=[
                "is_premium",
                "premium_expires_at",
                "premium_granted_at",
                "premium_grant_note",
                "premium_product_id",
                "updated_at",
            ]
        )
        return
    guest_exp = guest.premium_expires_at
    target_exp = target.premium_expires_at
    if guest_exp is None:
        return
    if target_exp is None:
        return
    if guest_exp <= target_exp:
        return
    target.premium_expires_at = guest_exp
    if guest.premium_product_id and not target.premium_product_id:
        target.premium_product_id = guest.premium_product_id
    target.save(
        update_fields=["premium_expires_at", "premium_product_id", "updated_at"]
    )


def _move_or_drop_unique_rows(model, *, guest: AppUser, target: AppUser, key_fields: tuple[str, ...]) -> None:
    """Misafir FK kayıtlarını hedefe taşır; çakışanları siler."""
    for row in model.objects.filter(user=guest).iterator():
        lookup = {field: getattr(row, field) for field in key_fields}
        lookup["user"] = target
        if model.objects.filter(**lookup).exists():
            row.delete()
        else:
            row.user = target
            row.save(update_fields=["user"])


def merge_guest_user_into(*, guest: AppUser, target: AppUser) -> None:
    """Misafir AppUser verisini kalıcı hesaba birleştirip misafir satırını siler."""
    if guest.pk == target.pk:
        return
    if not guest.is_anonymous:
        return
    if target.is_anonymous:
        return

    from .models import (
        DailyMiniExamAttempt,
        DailyMiniRankingWinner,
        DailySubjectFreeUsage,
        DeviceToken,
        PromoCodeRedemption,
        QuestionAttempt,
        QuestionErrorReport,
        QuestionRating,
        QuestionView,
        TopicTestCompletion,
        UserMessage,
    )

    with transaction.atomic():
        guest = AppUser.objects.select_for_update().get(pk=guest.pk)
        target = AppUser.objects.select_for_update().get(pk=target.pk)
        if not guest.is_anonymous or target.is_anonymous or guest.pk == target.pk:
            return

        _merge_premium_fields(guest=guest, target=target)

        _move_or_drop_unique_rows(
            QuestionAttempt, guest=guest, target=target, key_fields=("question",)
        )
        _move_or_drop_unique_rows(
            QuestionView, guest=guest, target=target, key_fields=("question",)
        )
        _move_or_drop_unique_rows(
            QuestionRating, guest=guest, target=target, key_fields=("question",)
        )
        _move_or_drop_unique_rows(
            TopicTestCompletion, guest=guest, target=target, key_fields=("topic_test",)
        )
        _move_or_drop_unique_rows(
            DailySubjectFreeUsage,
            guest=guest,
            target=target,
            key_fields=("subject_slug", "day"),
        )
        _move_or_drop_unique_rows(
            QuestionErrorReport, guest=guest, target=target, key_fields=("question",)
        )
        _move_or_drop_unique_rows(
            DailyMiniExamAttempt,
            guest=guest,
            target=target,
            key_fields=("exam_date", "kpss_type"),
        )
        _move_or_drop_unique_rows(
            PromoCodeRedemption, guest=guest, target=target, key_fields=("promo_code",)
        )

        for token_row in DeviceToken.objects.filter(user=guest):
            if DeviceToken.objects.filter(token=token_row.token).exclude(pk=token_row.pk).exists():
                token_row.delete()
            else:
                token_row.user = target
                token_row.save(update_fields=["user"])

        UserMessage.objects.filter(user=guest).update(user=target)
        DailyMiniRankingWinner.objects.filter(user=guest).update(user=target)

        guest.delete()


def purge_orphan_guest_after_merge(*, guest_sub: str, keep_user: AppUser) -> bool:
    """
    Misafir → Google birleşiminde eski anonim satırı temizler.
    Aynı Firebase UID ile yükseltmede (link başarılı) no-op.
    """
    guest_sub = (guest_sub or "").strip()
    if not guest_sub or keep_user.is_anonymous:
        return False
    if guest_sub == (keep_user.google_sub or "").strip():
        return False

    guest = (
        AppUser.objects.filter(google_sub=guest_sub, is_anonymous=True)
        .exclude(pk=keep_user.pk)
        .first()
    )
    if guest is None:
        return False

    merge_guest_user_into(guest=guest, target=keep_user)
    logger.info(
        "Misafir hesap birleştirildi guest_sub=%s → user_id=%s",
        guest_sub,
        keep_user.pk,
    )
    return True


def resolve_guest_sub_for_merge(request, guest_sub_param: str = "") -> str:
    """İstek gövdesi veya Bearer misafir oturumundan eski Firebase UID."""
    guest_sub = (guest_sub_param or "").strip()
    if guest_sub:
        return guest_sub
    prior = get_user_from_request(request)
    if prior is not None and prior.is_anonymous:
        return (prior.google_sub or "").strip()
    return ""


def upsert_app_user(claims: dict[str, Any], *, guest_sub: str = "") -> AppUser:
    """Geriye dönük uyumluluk."""
    claims = dict(claims)
    claims.setdefault("is_anonymous", False)
    return upsert_firebase_user(claims, guest_sub=guest_sub)


def user_to_dict(user: AppUser) -> dict[str, Any]:
    from datetime import timedelta

    from django.utils import timezone

    email = user.email or ""
    if user.is_anonymous or is_guest_email(email):
        email = ""
    name_change_available_at = None
    changed_at = getattr(user, "display_name_changed_at", None)
    if changed_at is not None:
        name_change_available_at = changed_at + timedelta(days=7)
        if name_change_available_at <= timezone.now():
            name_change_available_at = None
    return {
        "id": str(user.pk),
        "isim": user.display_name or "Misafir",
        "eposta": email,
        "isimDegistirilebilirAt": (
            name_change_available_at.isoformat()
            if name_change_available_at
            else None
        ),
        "isPremium": user.premium_active,
        "isAnonymous": user.is_anonymous,
        "premiumProductId": user.premium_product_id or "",
        "isYearlyPremium": user.is_yearly_premium,
        "premiumBitisTarihi": (
            user.premium_expires_at.isoformat()
            if user.premium_expires_at
            else None
        ),
        "premiumVerilisTarihi": (
            user.premium_granted_at.isoformat()
            if user.premium_granted_at
            else None
        ),
        "premiumGrantNote": user.premium_grant_note or None,
        "photoUrl": user.photo_url or None,
        "createdAt": user.created_at.isoformat() if user.created_at else None,
        "lastLoginAt": (
            user.last_login_at.isoformat() if user.last_login_at else None
        ),
    }


def get_user_from_request(request) -> AppUser | None:
    header = request.headers.get("Authorization") or request.META.get(
        "HTTP_AUTHORIZATION", ""
    )
    if not header.lower().startswith("bearer "):
        return None
    token = header[7:].strip()
    if not token:
        return None
    user = (
        AppUser.objects.filter(api_token=token, is_active=True)
        .only(
            "id",
            "google_sub",
            "email",
            "display_name",
            "display_name_changed_at",
            "photo_url",
            "is_anonymous",
            "is_premium",
            "premium_expires_at",
            "premium_granted_at",
            "premium_grant_note",
            "premium_product_id",
            "api_token",
            "is_active",
        )
        .first()
    )
    if user is not None:
        touch_user_activity(user.pk)
    return user


def touch_user_activity(user_id: int, *, min_interval_seconds: int = 120) -> None:
    """Canlı oturum sayacı — sık API çağrılarında DB yazısını sınırlar."""
    from datetime import timedelta

    from django.db.models import Q
    from django.utils import timezone

    now = timezone.now()
    threshold = now - timedelta(seconds=min_interval_seconds)
    AppUser.objects.filter(pk=user_id).filter(
        Q(last_active_at__isnull=True) | Q(last_active_at__lt=threshold)
    ).update(last_active_at=now)
