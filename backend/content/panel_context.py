from __future__ import annotations

from datetime import timedelta

from django.db.models import QuerySet
from django.utils import timezone

from .models import Question, QuestionErrorReport, TelegramBotSession


def pending_error_report_count() -> int:
    """Yalnızca incelenmeyi bekleyen (açık) bildirimler."""
    return QuestionErrorReport.objects.filter(status="open").count()


def telegram_solution_hold_question_ids(*, max_age_hours: int = 24) -> set[int]:
    """Evet/Hayır veya çözüm metni beklenen sorular — panele henüz düşmez."""
    cutoff = timezone.now() - timedelta(hours=max_age_hours)
    return set(
        TelegramBotSession.objects.filter(
            updated_at__gte=cutoff,
            question_id__isnull=False,
        ).values_list("question_id", flat=True)
    )


def pending_telegram_questions_qs() -> QuerySet[Question]:
    """Telegram onay kuyruğu — çözüm diyaloğu bitmeden soru yok."""
    qs = Question.objects.filter(
        submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        is_published=False,
    )
    hold = telegram_solution_hold_question_ids()
    if hold:
        qs = qs.exclude(pk__in=hold)
    return qs


def pending_telegram_question_count() -> int:
    """Telegram'dan gelip henüz yayınlanmamış + diyaloğu bitmiş sorular."""
    return pending_telegram_questions_qs().count()


def mark_question_error_reports_reviewed(question: Question) -> int:
    """Soru düzenlendiğinde açık bildirimleri incelendi say."""
    return QuestionErrorReport.objects.filter(
        question=question,
        status="open",
    ).update(status="reviewed", updated_at=timezone.now())


def panel_nav_context(request):
    """Panel yan menüsü — incelenecek soru sayacı."""
    count = 0
    pending_questions = 0
    user = getattr(request, "user", None)
    path = getattr(request, "path", "") or ""
    if (
        user
        and user.is_authenticated
        and user.is_staff
        and path.startswith("/panel/")
    ):
        count = pending_error_report_count()
        pending_questions = pending_telegram_question_count()
    return {
        "pending_error_report_count": count,
        "pending_telegram_question_count": pending_questions,
    }
