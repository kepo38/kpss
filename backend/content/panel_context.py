from __future__ import annotations

from django.utils import timezone

from .models import Question, QuestionErrorReport


def pending_error_report_count() -> int:
    """Yalnızca incelenmeyi bekleyen (açık) bildirimler."""
    return QuestionErrorReport.objects.filter(status="open").count()


def pending_telegram_question_count() -> int:
    """Telegram'dan gelip henüz yayınlanmamış sorular."""
    return Question.objects.filter(
        submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        is_published=False,
    ).count()


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
