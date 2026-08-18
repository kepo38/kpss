"""Şablondan deneme paketi üretimi."""

from __future__ import annotations

import random
from dataclasses import dataclass, field

from django.db import transaction
from django.utils.text import slugify

from .models import (
    ExamDistributionTemplate,
    ExamPack,
    ExamPackExam,
    ExamPackExamQuestion,
    Question,
    Topic,
)


class ExamPackGeneratorError(Exception):
    """Üretim sırasında havuz yetersiz veya şablon hatalı."""


def quality_question_qs(**filters):
    """En az 1000 cevaplı, kilitlenmiş orta zorlukta yayınlanmış sorular."""
    return Question.objects.filter(
        is_published=True,
        difficulty=Question.DIFFICULTY_MEDIUM,
        attempt_count__gte=Question.DIFFICULTY_MIN_ATTEMPTS,
        **filters,
    )


@dataclass
class _PickPlan:
    topic_id: int
    count: int


@dataclass
class _GeneratorState:
    used_question_ids: set[int] = field(default_factory=set)
    warnings: list[str] = field(default_factory=list)


def generate_pack_exams(
    pack: ExamPack,
    *,
    replace: bool = False,
    seed: int | None = None,
) -> list[ExamPackExam]:
    """Paket şablonuna göre deneme oturumları ve soru atamalarını üretir."""
    rng = random.Random(seed)
    state = _GeneratorState()

    plans = _distribution_plans(pack)
    if not plans:
        raise ExamPackGeneratorError(
            "Bu paket için dağılım şablonu bulunamadı. "
            "Önce panelden ExamDistributionTemplate satırları ekleyin."
        )

    total_needed = sum(row.count for row in plans) * pack.exam_count
    available = _count_available_questions(plans)
    if available < total_needed:
        raise ExamPackGeneratorError(
            f"Kaliteli orta soru havuzu yetersiz: en az {total_needed} soru "
            f"gerekli (1000+ cevap, orta zorluk), mevcut {available}."
        )

    with transaction.atomic():
        if replace:
            pack.exams.all().delete()

        created: list[ExamPackExam] = []
        for exam_index in range(1, pack.exam_count + 1):
            title = _exam_title(pack, exam_index)
            exam = ExamPackExam.objects.create(
                pack=pack,
                index=exam_index,
                title=title,
            )
            sort_order = 0
            for row in plans:
                picked = _pick_questions(
                    topic_id=row.topic_id,
                    count=row.count,
                    state=state,
                    rng=rng,
                )
                for question in picked:
                    ExamPackExamQuestion.objects.create(
                        exam=exam,
                        question=question,
                        sort_order=sort_order,
                    )
                    sort_order += 1
            created.append(exam)

    return created


def _distribution_plans(pack: ExamPack) -> list[_PickPlan]:
    """Paket türüne göre konu bazlı soru seçim planı."""
    if pack.pack_kind == ExamPack.PACK_KIND_BRANCH:
        if not pack.subject_id:
            raise ExamPackGeneratorError("Branş paketinde ders seçili olmalı.")
        templates = ExamDistributionTemplate.objects.filter(
            exam_type_id=pack.exam_type_id,
            subject_id=pack.subject_id,
        ).select_related("topic")
        return _plans_from_templates(templates, subject_id=pack.subject_id)

    templates = ExamDistributionTemplate.objects.filter(
        exam_type_id=pack.exam_type_id,
    ).select_related("subject", "topic")
    plans: list[_PickPlan] = []
    subject_ids = templates.values_list("subject_id", flat=True).distinct()
    for subject_id in subject_ids:
        subject_rows = templates.filter(subject_id=subject_id)
        plans.extend(_plans_from_templates(subject_rows, subject_id=subject_id))
    return plans


def _plans_from_templates(templates, *, subject_id: int) -> list[_PickPlan]:
    topic_rows = [t for t in templates if t.topic_id]
    subject_rows = [t for t in templates if not t.topic_id]

    if topic_rows:
        return [_PickPlan(topic_id=t.topic_id, count=t.question_count) for t in topic_rows]

    if not subject_rows:
        return []

    total = subject_rows[0].question_count
    topics = list(
        Topic.objects.filter(subject_id=subject_id, is_active=True).order_by(
            "sort_order", "id"
        )
    )
    if not topics:
        raise ExamPackGeneratorError(f"Ders #{subject_id} için aktif konu yok.")

    return _split_count_across_topics(topics, total)


def _split_count_across_topics(topics: list[Topic], total: int) -> list[_PickPlan]:
    """Ders toplamını konulara eşit dağıt (kalan ilk konulara +1)."""
    n = len(topics)
    base = total // n
    remainder = total % n
    plans: list[_PickPlan] = []
    for i, topic in enumerate(topics):
        count = base + (1 if i < remainder else 0)
        if count > 0:
            plans.append(_PickPlan(topic_id=topic.id, count=count))
    return plans


def _count_available_questions(plans: list[_PickPlan]) -> int:
    total = 0
    for row in plans:
        total += quality_question_qs(topic_id=row.topic_id).count()
    return total


def _pick_questions(
    *,
    topic_id: int,
    count: int,
    state: _GeneratorState,
    rng: random.Random,
) -> list[Question]:
    qs = quality_question_qs(topic_id=topic_id).exclude(
        id__in=state.used_question_ids
    )
    pool = list(qs)
    if len(pool) < count:
        raise ExamPackGeneratorError(
            f"Konu #{topic_id} için kaliteli orta soru yetersiz: "
            f"{count} istendi, {len(pool)} uygun soru kaldı. "
            "Aynı soru pakette tekrar kullanılmaz."
        )

    rng.shuffle(pool)
    picked = pool[:count]
    state.used_question_ids.update(q.id for q in picked)
    return picked


def _exam_title(pack: ExamPack, index: int) -> str:
    if pack.pack_kind == ExamPack.PACK_KIND_BRANCH and pack.subject_id:
        subject_name = pack.subject.name
        return f"{subject_name} Deneme {index}"
    return f"{pack.title} · Deneme {index}"


def new_pack_public_id(title: str) -> str:
    base = slugify(title, allow_unicode=False) or "pack"
    base = base.replace("-", "_")[:32]
    suffix = random.randint(1000, 9999)
    return f"ep_{base}_{suffix}"
