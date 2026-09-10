"""TG deneme puanlama."""

from __future__ import annotations

from decimal import Decimal
from typing import Iterable

from content.models import Question


def kpss_net(correct: int, wrong: int) -> Decimal:
    return Decimal(str(round(correct - wrong / 4.0, 2)))


def grade_attempt(
    question_ids: Iterable[str],
    answers: dict,
) -> tuple[int, int, int, dict[str, str], dict[str, float]]:
    """(correct, wrong, blank, graded_answers, subject_nets)."""
    ids = list(question_ids)
    questions = {
        q.public_id: q
        for q in Question.objects.filter(public_id__in=ids).select_related(
            "topic", "topic__subject"
        )
    }
    correct = wrong = blank = 0
    graded: dict[str, str] = {}
    subject_stats: dict[str, dict[str, int]] = {}

    for qid in ids:
        question = questions.get(qid)
        selected = str(answers.get(qid) or "").strip().upper()
        subject_slug = ""
        if question is not None:
            subject_slug = getattr(question.topic.subject, "slug", "") or ""

        if not selected:
            blank += 1
            if subject_slug:
                subject_stats.setdefault(subject_slug, {"correct": 0, "wrong": 0})
            continue

        graded[qid] = selected[:1]
        if question is None:
            blank += 1
            continue

        bucket = subject_stats.setdefault(
            subject_slug or "diger",
            {"correct": 0, "wrong": 0},
        )
        if selected[:1] == question.correct_option:
            correct += 1
            bucket["correct"] += 1
        else:
            wrong += 1
            bucket["wrong"] += 1

    subject_nets: dict[str, float] = {}
    for slug, stats in subject_stats.items():
        subject_nets[slug] = float(kpss_net(stats["correct"], stats["wrong"]))

    return correct, wrong, blank, graded, subject_nets
