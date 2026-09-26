"""Deneme oturumunu kullanıcının geçmiş cevaplarına göre kişiselleştirir."""

from __future__ import annotations

import math
import random

from .exam_pack_generator import ExamPackGeneratorError, quality_question_qs
from .models import Question, QuestionAttempt

# Bir oturumda daha önce cevaplanmış soruların üst sınırı.
MAX_PREVIOUSLY_ANSWERED_RATIO = 0.20


def max_previously_answered(total: int) -> int:
    if total <= 0:
        return 0
    return math.floor(total * MAX_PREVIOUSLY_ANSWERED_RATIO)


def personalize_exam_questions(
    questions: list[Question],
    user,
    *,
    seed: int | None = None,
) -> list[Question]:
    """En fazla %20'si kullanıcının daha önce cevapladığı soru olsun.

    Fazlası aynı konudan, henüz cevaplanmamış kaliteli orta sorularla değişir.
    """
    if not questions:
        return []
    if user is None or getattr(user, "is_anonymous", False):
        raise ExamPackGeneratorError("Google girişi gerekli.")

    question_ids = [q.id for q in questions]
    seen_ids = set(
        QuestionAttempt.objects.filter(
            user=user,
            question_id__in=question_ids,
        ).values_list("question_id", flat=True)
    )
    allowed_seen = max_previously_answered(len(questions))
    extra_seen = [q for q in questions if q.id in seen_ids][allowed_seen:]
    if not extra_seen:
        return questions

    extra_seen_ids = {q.id for q in extra_seen}
    keep_ids = {q.id for q in questions if q.id not in extra_seen_ids}
    rng = random.Random(seed)
    result: list[Question] = []
    used_ids = set(keep_ids)

    for question in questions:
        if question.id not in extra_seen_ids:
            result.append(question)
            continue
        replacement = _replacement_for(
            question,
            user=user,
            used_ids=used_ids,
            rng=rng,
        )
        if replacement is None:
            raise ExamPackGeneratorError(
                "Daha önce çözdüğünüz soruları değiştirmek için "
                "yeterli yeni kaliteli soru yok. Daha sonra deneyin."
            )
        used_ids.add(replacement.id)
        result.append(replacement)
    return result


def _replacement_for(
    question: Question,
    *,
    user,
    used_ids: set[int],
    rng: random.Random,
) -> Question | None:
    attempted = QuestionAttempt.objects.filter(user=user).values_list(
        "question_id", flat=True
    )
    qs = (
        quality_question_qs(topic_id=question.topic_id)
        .exclude(id__in=used_ids)
        .exclude(id__in=attempted)
    )
    pool = list(qs)
    if not pool:
        qs = (
            quality_question_qs(topic__subject_id=question.topic.subject_id)
            .exclude(id__in=used_ids)
            .exclude(id__in=attempted)
        )
        pool = list(qs)
    if not pool:
        return None
    rng.shuffle(pool)
    return pool[0]
