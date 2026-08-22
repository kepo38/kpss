"""TG deneme sıralama ve sonuç yayını."""

from __future__ import annotations

from django.utils import timezone

from content.models import TgExam, TgExamAttempt


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


def publish_exam_results(exam: TgExam, *, send_push: bool = True) -> bool:
    now = timezone.now()
    if exam.is_results_published:
        return False
    if now < exam.end_at:
        return False

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
