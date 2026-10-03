"""TG deneme durum makinesi (mobil karşılama ekranı)."""

from __future__ import annotations

from django.utils import timezone

from content.models import TgExam, TgExamAttempt


def exam_status(exam: TgExam, attempt: TgExamAttempt | None, *, now=None) -> str:
    current = now or timezone.now()
    if current < exam.start_at:
        return "not_started"
    if attempt is not None and attempt.is_submitted:
        if exam.is_results_published:
            return "results"
        return "submitted_waiting"
    if current >= exam.end_at:
        if exam.is_results_published:
            return "results"
        return "ended"
    if attempt is not None and not attempt.is_submitted:
        return "in_progress"
    return "active"
