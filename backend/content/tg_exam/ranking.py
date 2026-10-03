"""TG deneme sıralama ve sonuç yayını."""

from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from content.models import TgExam, TgExamAttempt

from .grading import grade_attempt, kpss_net


def refresh_exam_rankings(exam_id: int) -> None:
    attempts = list(
        TgExamAttempt.objects.filter(exam_id=exam_id, is_submitted=True).order_by(
            "-net", "duration_seconds", "submitted_at"
        )
    )
    for index, attempt in enumerate(attempts, start=1):
        if attempt.ranking != index:
            attempt.ranking = index
            attempt.save(update_fields=["ranking"])


def auto_submit_open_attempts(exam: TgExam) -> int:
    """end_at sonrası gönderilmemiş oturumları kaydedilmiş cevaplarla kapat."""
    now = timezone.now()
    question_ids = list(exam.question_ids or [])
    submitted = 0
    open_qs = TgExamAttempt.objects.filter(exam=exam, is_submitted=False)
    for attempt in open_qs.iterator():
        with transaction.atomic():
            locked = (
                TgExamAttempt.objects.select_for_update()
                .filter(pk=attempt.pk, is_submitted=False)
                .first()
            )
            if locked is None:
                continue
            raw_answers = locked.answers if isinstance(locked.answers, dict) else {}
            correct, wrong, blank, graded, subject_nets = grade_attempt(
                question_ids, raw_answers
            )
            locked.answers = graded
            locked.correct = correct
            locked.wrong = wrong
            locked.blank = blank
            locked.net = kpss_net(correct, wrong)
            locked.subject_nets = subject_nets
            locked.duration_seconds = max(
                int(locked.duration_seconds or 0),
                int(locked.elapsed_seconds or 0),
            )
            locked.is_submitted = True
            locked.submitted_at = now
            locked.save(
                update_fields=[
                    "answers",
                    "correct",
                    "wrong",
                    "blank",
                    "net",
                    "subject_nets",
                    "duration_seconds",
                    "is_submitted",
                    "submitted_at",
                ]
            )
            submitted += 1
    return submitted


def publish_exam_results(exam: TgExam, *, send_push: bool = True) -> bool:
    now = timezone.now()
    if exam.is_results_published:
        return False
    if now < exam.end_at:
        return False

    auto_submit_open_attempts(exam)
    refresh_exam_rankings(exam.pk)
    exam.is_results_published = True
    exam.results_published_at = now
    exam.save(
        update_fields=[
            "is_results_published",
            "results_published_at",
            "updated_at",
        ]
    )

    if send_push and exam.results_push_sent_at is None:
        from content.push import send_tg_exam_results_push

        result = send_tg_exam_results_push(exam)
        exam.results_push_sent_at = timezone.now()
        exam.results_push_success_count = result.success
        exam.results_push_fail_count = result.failure
        exam.save(
            update_fields=[
                "results_push_sent_at",
                "results_push_success_count",
                "results_push_fail_count",
                "updated_at",
            ]
        )
    return True


def finalize_due_tg_exams(*, send_push: bool = True) -> list[int]:
    now = timezone.now()
    due = TgExam.objects.filter(
        is_published=True,
        is_results_published=False,
        end_at__lte=now,
    )
    published_ids: list[int] = []
    for exam in due:
        if publish_exam_results(exam, send_push=send_push):
            published_ids.append(exam.pk)
    return published_ids
