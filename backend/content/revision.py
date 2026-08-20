"""İçerik sürümü — soru/test/bilgi değişince mobil anında senkronlar."""

from __future__ import annotations

import logging
import threading

from django.conf import settings
from django.db import transaction
from django.db.models import F
from django.db.models.signals import m2m_changed, post_delete, post_save
from django.dispatch import receiver
from django.utils import timezone

from .models import (
    ContentRevision,
    Question,
    Subject,
    Topic,
    TopicLesson,
    TopicSummaryCard,
    TopicTest,
)

logger = logging.getLogger(__name__)

_push_lock = threading.Lock()
_push_timer: threading.Timer | None = None


def get_content_version() -> int:
    obj, _ = ContentRevision.objects.get_or_create(
        pk=1, defaults={"version": 1}
    )
    return int(obj.version)


def bump_content_revision(*, send_push: bool = True) -> int:
    """İçerik değişti — sürümü artır, isteğe bağlı FCM sessiz bildirim."""
    with transaction.atomic():
        obj, _ = ContentRevision.objects.select_for_update().get_or_create(
            pk=1, defaults={"version": 1}
        )
        ContentRevision.objects.filter(pk=1).update(
            version=F("version") + 1,
            updated_at=timezone.now(),
        )
        obj.refresh_from_db()
        version = int(obj.version)

    if send_push:
        _schedule_content_push(version)
    return version


def _schedule_content_push(version: int) -> None:
    """Ardışık kayıtlarda FCM spam’ini önlemek için kısa gecikme."""
    global _push_timer
    delay = float(getattr(settings, "CONTENT_PUSH_DEBOUNCE_SECONDS", 2.0))

    def _fire() -> None:
        global _push_timer
        with _push_lock:
            _push_timer = None
        try:
            from .push import notify_content_updated

            notify_content_updated(version)
        except Exception:  # noqa: BLE001
            logger.exception("content update push failed")

    with _push_lock:
        if _push_timer is not None:
            _push_timer.cancel()
        _push_timer = threading.Timer(delay, _fire)
        _push_timer.daemon = True
        _push_timer.start()


def _bump_from_signal(**kwargs) -> None:
    try:
        bump_content_revision(send_push=True)
    except Exception:  # noqa: BLE001
        logger.exception("content revision bump failed")


@receiver(post_save, sender=Question)
@receiver(post_delete, sender=Question)
@receiver(post_save, sender=TopicTest)
@receiver(post_delete, sender=TopicTest)
@receiver(post_save, sender=TopicLesson)
@receiver(post_delete, sender=TopicLesson)
@receiver(post_save, sender=TopicSummaryCard)
@receiver(post_delete, sender=TopicSummaryCard)
@receiver(post_save, sender=Topic)
@receiver(post_delete, sender=Topic)
@receiver(post_save, sender=Subject)
@receiver(post_delete, sender=Subject)
def content_changed(sender, **kwargs):  # noqa: ARG001
    _bump_from_signal()


@receiver(m2m_changed, sender=TopicTest.questions.through)
def test_questions_changed(sender, **kwargs):  # noqa: ARG001
    action = kwargs.get("action") or ""
    if action.startswith("post_"):
        _bump_from_signal()
