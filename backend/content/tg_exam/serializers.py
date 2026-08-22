"""TG deneme API yanıt gövdeleri."""

from __future__ import annotations

from django.db.models import Avg, Count
from django.utils import timezone

from content.models import TgExam, TgExamAttempt

from .status import exam_status


def exam_aggregate_stats(exam_id: int) -> dict:
    qs = TgExamAttempt.objects.filter(exam_id=exam_id, is_submitted=True)
    agg = qs.aggregate(
        participants=Count("id"),
        avg_net=Avg("net"),
    )
    return {
        "participantCount": agg["participants"] or 0,
        "averageNet": float(agg["avg_net"] or 0),
    }


def attempt_to_dict(
    attempt: TgExamAttempt | None,
    *,
    exam: TgExam,
    include_rank: bool,
) -> dict | None:
    if attempt is None:
        return None
    payload = {
        "correct": attempt.correct,
        "wrong": attempt.wrong,
        "blank": attempt.blank,
        "net": float(attempt.net),
        "subjectNets": attempt.subject_nets or {},
        "durationSeconds": attempt.duration_seconds,
        "isSubmitted": attempt.is_submitted,
        "currentIndex": attempt.current_index,
        "elapsedSeconds": attempt.elapsed_seconds,
        "answers": attempt.answers or {},
    }
    if include_rank and attempt.is_submitted:
        payload["ranking"] = attempt.ranking
        payload["successPercent"] = (
            round(attempt.correct / max(len(exam.question_ids), 1) * 100, 1)
            if exam.question_ids
            else 0.0
        )
    return payload


def exam_to_dict(
    exam: TgExam,
    *,
    attempt: TgExamAttempt | None = None,
    now=None,
) -> dict:
    current = now or timezone.now()
    status = exam_status(exam, attempt, now=current)
    include_rank = exam.is_results_published
    stats = exam_aggregate_stats(exam.pk) if include_rank else {}
    participant_count = stats.get("participantCount", 0)
    if not include_rank and attempt is not None and attempt.is_submitted:
        participant_count = TgExamAttempt.objects.filter(
            exam_id=exam.pk, is_submitted=True
        ).count()

    return {
        "id": exam.pk,
        "title": exam.title,
        "kpssType": exam.kpss_type,
        "startAt": exam.start_at.isoformat(),
        "endAt": exam.end_at.isoformat(),
        "durationMinutes": exam.duration_minutes,
        "questionCount": exam.question_count,
        "questionIds": list(exam.question_ids or []),
        "isResultsPublished": exam.is_results_published,
        "resultsPublishedAt": (
            exam.results_published_at.isoformat()
            if exam.results_published_at
            else None
        ),
        "status": status,
        "myAttempt": attempt_to_dict(
            attempt, exam=exam, include_rank=include_rank
        ),
        "participantCount": participant_count,
        "averageNet": stats.get("averageNet") if include_rank else None,
    }
