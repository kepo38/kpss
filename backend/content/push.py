"""Firebase Cloud Messaging — Play Store / uygulama bildirimleri."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path

from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


def _announcement_image_url(announcement) -> str | None:
    """FCM / data payload için mutlak görsel URL (PUBLIC_BASE_URL gerekir)."""
    if not getattr(announcement, "image", None):
        return None
    try:
        rel = announcement.image.url
    except ValueError:
        return None
    if rel.startswith("http://") or rel.startswith("https://"):
        return rel
    base = (getattr(settings, "PUBLIC_BASE_URL", "") or "").rstrip("/")
    if not base:
        return None
    return f"{base}{rel}"


@dataclass
class PushResult:
    ok: bool
    success: int = 0
    failure: int = 0
    topic_ok: bool = False
    error: str = ""


def firebase_ready() -> tuple[bool, str]:
    """Servis hesabı dosyası var mı?"""
    path = Path(getattr(settings, "FIREBASE_CREDENTIALS", "") or "")
    if not path.is_file():
        return (
            False,
            "Firebase servis hesabı yok. "
            f"`{path}` dosyasını ekleyin (Firebase Console > Project settings > Service accounts).",
        )
    try:
        import firebase_admin  # noqa: F401
    except ImportError:
        return False, "firebase-admin paketi kurulu değil (`pip install firebase-admin`)."
    return True, ""


def _ensure_firebase_app():
    import firebase_admin
    from firebase_admin import credentials

    try:
        return firebase_admin.get_app()
    except ValueError:
        path = Path(settings.FIREBASE_CREDENTIALS)
        cred = credentials.Certificate(str(path))
        return firebase_admin.initialize_app(cred)


def notify_content_updated(version: int) -> bool:
    """
    Sessiz FCM: uygulama açıkken / arka planda paket senkronu tetikler.
    Kullanıcıya görünür duyuru göstermez.
    """
    ready, _ = firebase_ready()
    if not ready:
        return False
    try:
        from firebase_admin import messaging

        _ensure_firebase_app()
        topic = getattr(settings, "FCM_CONTENT_TOPIC", "kpss_content") or "kpss_content"
        messaging.send(
            messaging.Message(
                topic=topic,
                data={
                    "type": "content_update",
                    "version": str(version),
                },
                android=messaging.AndroidConfig(priority="high"),
            )
        )
        return True
    except Exception:  # noqa: BLE001
        logger.exception("notify_content_updated failed")
        return False


def send_announcement_push(announcement) -> PushResult:
    """
    Duyuruyu FCM ile gönder.
    1) Konu (topic): tüm abone cihazlar
    2) Kayıtlı DeviceToken listesi (multicast)
    """
    ready, err = firebase_ready()
    if not ready:
        return PushResult(ok=False, error=err)

    from firebase_admin import messaging

    from .models import DeviceToken

    try:
        _ensure_firebase_app()
    except Exception as exc:  # noqa: BLE001
        return PushResult(ok=False, error=f"Firebase başlatılamadı: {exc}")

    title = (announcement.title or "").strip() or "KPSS Odak"
    body = (announcement.body or "").strip()
    if not body:
        body = "Yeni duyuru — uygulamada görüntüle" if announcement.image else title

    image_url = _announcement_image_url(announcement)
    data = {
        "type": "announcement",
        "announcement_id": str(announcement.pk),
        "title": title,
        "body": body[:500],
    }
    if image_url:
        data["image_url"] = image_url

    android_notification_kwargs: dict = {
        "title": title,
        "body": body,
        "channel_id": "announcements",
        "sound": "default",
    }
    if image_url:
        # Genişletilmiş big-picture stili (Hepsiburada benzeri)
        android_notification_kwargs["image"] = image_url

    android = messaging.AndroidConfig(
        priority="high",
        notification=messaging.AndroidNotification(**android_notification_kwargs),
    )
    note_kwargs: dict = {"title": title, "body": body}
    if image_url:
        note_kwargs["image"] = image_url
    note = messaging.Notification(**note_kwargs)

    success = 0
    failure = 0
    topic_ok = False
    topic = getattr(settings, "FCM_ANNOUNCEMENT_TOPIC", "kpss_duyuru") or "kpss_duyuru"

    try:
        messaging.send(
            messaging.Message(
                topic=topic,
                notification=note,
                data=data,
                android=android,
            )
        )
        topic_ok = True
        success += 1
    except Exception as exc:  # noqa: BLE001
        logger.warning("FCM topic send failed: %s", exc)
        failure += 1

    tokens = list(
        DeviceToken.objects.filter(is_active=True).values_list("token", flat=True)
    )
    # Multicast max 500
    for i in range(0, len(tokens), 500):
        chunk = tokens[i : i + 500]
        if not chunk:
            continue
        try:
            resp = messaging.send_each_for_multicast(
                messaging.MulticastMessage(
                    tokens=chunk,
                    notification=note,
                    data=data,
                    android=android,
                )
            )
            success += resp.success_count
            failure += resp.failure_count
            # Geçersiz jetonları pasifleştir
            for idx, send_resp in enumerate(resp.responses):
                if send_resp.success:
                    continue
                err_code = ""
                if send_resp.exception is not None:
                    err_code = getattr(send_resp.exception, "code", "") or str(
                        send_resp.exception
                    )
                if any(
                    x in err_code
                    for x in (
                        "registration-token-not-registered",
                        "invalid-registration-token",
                        "NOT_FOUND",
                        "UNREGISTERED",
                    )
                ):
                    DeviceToken.objects.filter(token=chunk[idx]).update(is_active=False)
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM multicast failed")
            failure += len(chunk)
            if not topic_ok:
                return PushResult(
                    ok=False,
                    success=success,
                    failure=failure,
                    topic_ok=topic_ok,
                    error=str(exc),
                )

    announcement.push_sent_at = timezone.now()
    announcement.push_success_count = success
    announcement.push_fail_count = failure
    announcement.is_published = True
    announcement.save(
        update_fields=[
            "push_sent_at",
            "push_success_count",
            "push_fail_count",
            "is_published",
            "updated_at",
        ]
    )

    if not topic_ok and success == 0:
        return PushResult(
            ok=False,
            success=success,
            failure=failure,
            topic_ok=topic_ok,
            error="Bildirim gönderilemedi. Firebase ayarlarını ve cihaz jetonlarını kontrol edin.",
        )

    return PushResult(
        ok=True,
        success=success,
        failure=failure,
        topic_ok=topic_ok,
    )


def _deactivate_bad_tokens(chunk: list[str], responses) -> None:
    from .models import DeviceToken

    for idx, send_resp in enumerate(responses):
        if send_resp.success:
            continue
        err_code = ""
        if send_resp.exception is not None:
            err_code = getattr(send_resp.exception, "code", "") or str(
                send_resp.exception
            )
        if any(
            x in err_code
            for x in (
                "registration-token-not-registered",
                "invalid-registration-token",
                "NOT_FOUND",
                "UNREGISTERED",
            )
        ):
            DeviceToken.objects.filter(token=chunk[idx]).update(is_active=False)


def send_user_message_push(message) -> PushResult:
    """Tek kullanıcının cihazlarına FCM mesajı gönder."""
    ready, err = firebase_ready()
    if not ready:
        return PushResult(ok=False, error=err)

    from firebase_admin import messaging

    from .models import DeviceToken

    try:
        _ensure_firebase_app()
    except Exception as exc:  # noqa: BLE001
        return PushResult(ok=False, error=f"Firebase başlatılamadı: {exc}")

    title = (message.title or "").strip() or "KPSS Odak"
    body = (message.body or "").strip() or title
    data = {
        "type": "user_message",
        "message_id": str(message.pk),
        "title": title,
        "body": body[:500],
    }
    android = messaging.AndroidConfig(
        priority="high",
        notification=messaging.AndroidNotification(
            title=title,
            body=body,
            channel_id="announcements",
            sound="default",
        ),
    )
    note = messaging.Notification(title=title, body=body)

    tokens = list(
        DeviceToken.objects.filter(
            user=message.user, is_active=True
        ).values_list("token", flat=True)
    )
    if not tokens:
        return PushResult(
            ok=False,
            error="Bu kullanıcının kayıtlı cihaz jetonu yok. "
            "Uygulamayı açıp bildirim izni vermiş olmalı.",
        )

    success = 0
    failure = 0
    for i in range(0, len(tokens), 500):
        chunk = tokens[i : i + 500]
        try:
            resp = messaging.send_each_for_multicast(
                messaging.MulticastMessage(
                    tokens=chunk,
                    notification=note,
                    data=data,
                    android=android,
                )
            )
            success += resp.success_count
            failure += resp.failure_count
            _deactivate_bad_tokens(chunk, resp.responses)
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM user message failed")
            return PushResult(
                ok=False,
                success=success,
                failure=failure + len(chunk),
                error=str(exc),
            )

    message.push_sent_at = timezone.now()
    message.push_success_count = success
    message.push_fail_count = failure
    message.save(
        update_fields=[
            "push_sent_at",
            "push_success_count",
            "push_fail_count",
        ]
    )

    if success == 0:
        return PushResult(
            ok=False,
            success=success,
            failure=failure,
            error="Bildirim hiçbir cihaza ulaşmadı.",
        )
    return PushResult(ok=True, success=success, failure=failure)
