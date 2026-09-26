"""TG deneme duyuru bildirimi — sınavdan 2 saat önce tüm kullanıcılara."""

from __future__ import annotations

from datetime import timedelta

from django.utils import timezone

from content.models import TgExam

# Başlangıç saatinden kaç saat önce FCM gider.
TG_EXAM_ANNOUNCEMENT_LEAD = timedelta(hours=2)

TG_EXAM_PUSH_CHANNEL = "tg_exams"
TG_EXAM_PUSH_COLOR = "#C41E3A"
TG_EXAM_DURATION_MINUTES = 130

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


def _exam_title(exam: TgExam) -> str:
    return (exam.title or "").strip() or "TG Denemesi"


def _metrics_label(exam: TgExam) -> str:
    count = exam.question_count or 120
    duration = exam.duration_minutes or TG_EXAM_DURATION_MINUTES
    return f"{count} soru · {duration} dk · Eş zamanlı"


def build_announcement_push_payload(exam: TgExam) -> dict[str, str]:
    """Premium TG duyuru metni — kısa başlık + genişletilebilir satırlar."""
    exam_title = _exam_title(exam)
    when_label = format_tr_exam_moment(exam.start_at)
    metrics = _metrics_label(exam)
    return {
        "title": exam_title,
        "body": f"2 saat sonra başlıyor · {when_label} · Yerini ayırt",
        "headline": "Türkiye Geneli Deneme",
        "exam_title": exam_title,
        "starts_at_label": when_label,
        "metrics_label": metrics,
        "cta_hint": "Denemeye git →",
    }


def build_announcement_push_copy(exam: TgExam) -> tuple[str, str]:
    """(title, body) — FCM notification alanları."""
    payload = build_announcement_push_payload(exam)
    return payload["title"], payload["body"]


def build_results_push_payload(exam: TgExam) -> dict[str, str]:
    exam_title = _exam_title(exam)
    return {
        "title": f"Sonuçların hazır · {exam_title}",
        "body": "Türkiye Geneli sıralaman açıklandı · Sıralamayı gör →",
        "headline": "Türkiye Geneli Deneme",
        "exam_title": exam_title,
        "starts_at_label": "",
        "metrics_label": "Detaylı analiz ve çözümler seni bekliyor",
        "cta_hint": "Sonuçları gör →",
    }


def build_results_push_copy(exam: TgExam) -> tuple[str, str]:
    payload = build_results_push_payload(exam)
    return payload["title"], payload["body"]


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

    result = send_tg_exam_announcement_push(exam)
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
