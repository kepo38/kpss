"""TG deneme duyuru bildirimi — sınavdan 2 saat önce tüm kullanıcılara."""

from __future__ import annotations

from datetime import timedelta

from django.utils import timezone

from content.models import TgExam

# Başlangıç saatinden kaç saat önce FCM gider.
TG_EXAM_ANNOUNCEMENT_LEAD = timedelta(hours=2)

_TR_MONTHS = (
    "",
    "Ocak",
    "Şubat",
    "Mart",
    "Nisan",
    "Mayıs",
    "Haziran",
    "Temmuz",
    "Ağustos",
    "Eylül",
    "Ekim",
    "Kasım",
    "Aralık",
)


def announcement_push_due_at(exam: TgExam):
    """Bildirimin gönderilmesi gereken an (başlangıç − 2 saat)."""
    return exam.start_at - TG_EXAM_ANNOUNCEMENT_LEAD


def format_tr_exam_moment(dt) -> str:
    local = timezone.localtime(dt)
    month = _TR_MONTHS[local.month]
    return f"{local.day} {month} · {local.strftime('%H:%M')}"


def build_announcement_push_copy(exam: TgExam) -> tuple[str, str]:
    """(title, body) — FCM duyuru metni."""
    title = "Türkiye Geneli Deneme"
    exam_title = (exam.title or "").strip() or "TG Denemesi"
    when_label = format_tr_exam_moment(exam.start_at)
    body = (
        f"「{exam_title}」2 saat içinde başlıyor ({when_label}). "
        f"Sıra sende — şimdi katıl, yerini ayırt!"
    )
    return title, body


def send_scheduled_tg_exam_announcement(
    exam: TgExam,
    *,
    send_push: bool = True,
    force: bool = False,
) -> bool:
    """
    Zamanı geldiyse duyuru FCM gönder. Idempotent.
    force=True: admin manuel gönderim (zaman penceresi yok sayılır).
    """
    if exam.announcement_push_sent_at is not None and not force:
        return False
    if not exam.is_published:
        return False

    now = timezone.now()
    if not force:
        if now < announcement_push_due_at(exam):
            return False
        if now >= exam.start_at:
            return False

    if not send_push:
        exam.announcement_push_sent_at = now
        exam.save(update_fields=["announcement_push_sent_at", "updated_at"])
        return True

    from content.push import send_tg_exam_announcement_push

    title, body = build_announcement_push_copy(exam)
    result = send_tg_exam_announcement_push(exam, title=title, body=body)
    exam.announcement_push_sent_at = now
    exam.announcement_push_success_count = result.success
    exam.announcement_push_fail_count = result.failure
    exam.save(
        update_fields=[
            "announcement_push_sent_at",
            "announcement_push_success_count",
            "announcement_push_fail_count",
            "updated_at",
        ]
    )
    return result.ok or result.topic_ok


def dispatch_due_tg_exam_announcements(*, send_push: bool = True) -> list[int]:
    """Başlangıçtan 2 saat önce penceresine giren yayınlanmış denemeler."""
    now = timezone.now()
    window_end = now + TG_EXAM_ANNOUNCEMENT_LEAD
    due = TgExam.objects.filter(
        is_published=True,
        announcement_push_sent_at__isnull=True,
        start_at__lte=window_end,
        start_at__gt=now,
    )
    sent_ids: list[int] = []
    for exam in due:
        if send_scheduled_tg_exam_announcement(exam, send_push=send_push):
            sent_ids.append(exam.pk)
    return sent_ids
