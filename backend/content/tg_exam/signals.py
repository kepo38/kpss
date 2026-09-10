"""TG deneme yayınlandığında soru cooldown kaydı."""

from __future__ import annotations

from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from content.models import TgExam

from .cooldown import record_tg_exam_question_usage


@receiver(pre_save, sender=TgExam)
def _cache_tg_exam_publish_state(sender, instance: TgExam, **kwargs) -> None:
    instance._was_published_before_save = False  # noqa: SLF001
    if instance.pk:
        instance._was_published_before_save = TgExam.objects.filter(  # noqa: SLF001
            pk=instance.pk, is_published=True
        ).exists()


@receiver(post_save, sender=TgExam)
def _tg_exam_record_usage_on_publish(
    sender,
    instance: TgExam,
    **kwargs,
) -> None:
    was_published = getattr(instance, "_was_published_before_save", False)
    publish_flip = instance.is_published and not was_published
    if (
        publish_flip
        and instance.question_ids
        and not instance.tg_usage_recorded
    ):
        record_tg_exam_question_usage(instance)
        TgExam.objects.filter(pk=instance.pk).update(tg_usage_recorded=True)


def connect() -> None:
    """Sinyaller modül import edilince otomatik bağlanır; test için açık API."""
