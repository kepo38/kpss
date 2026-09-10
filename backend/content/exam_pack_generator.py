"""Şablondan deneme paketi üretimi."""

from __future__ import annotations

import random
from dataclasses import dataclass, field

from django.db import transaction
from django.db.models import Count
from django.utils.text import slugify

from content.osym_exam_order import (
    OSYM_FULL_EXAM,
    full_exam_slot_count,
    osym_slots_for_subject,
    scale_osym_slots,
    subject_canonical_key,
)
from content.tg_exam.distribution import SUBJECT_SLUG_ALIASES

from .models import (
    ExamDistributionTemplate,
    ExamPack,
    ExamPackExam,
    ExamPackExamQuestion,
    Question,
    Subject,
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
    topic_id: int | None = None
    subject_id: int | None = None
    topic_slugs: list[str] = field(default_factory=list)
    count: int = 0
    subtopic: str = ""
    scenario_group: bool = False


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
                    plan=row,
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
        total = _template_question_total(templates)
        osym = _osym_plans_for_subject(
            subject=pack.subject,
            target_total=total,
        )
        if osym:
            return osym
        return _plans_from_templates(templates, subject_id=pack.subject_id)

    templates = ExamDistributionTemplate.objects.filter(
        exam_type_id=pack.exam_type_id,
    ).select_related("subject", "topic")
    total = _template_question_total(templates)
    if total <= 0:
        total = full_exam_slot_count()
    osym = _osym_plans_for_full_exam(target_total=total)
    if osym:
        return osym

    plans: list[_PickPlan] = []
    subject_ids = templates.values_list("subject_id", flat=True).distinct()
    for subject_id in subject_ids:
        subject_rows = templates.filter(subject_id=subject_id)
        plans.extend(_plans_from_templates(subject_rows, subject_id=subject_id))
    return plans


def _template_question_total(templates) -> int:
    topic_rows = [t for t in templates if t.topic_id]
    if topic_rows:
        return sum(t.question_count for t in topic_rows)
    subject_rows = [t for t in templates if not t.topic_id]
    if subject_rows:
        return subject_rows[0].question_count
    return 0


def _osym_plans_for_subject(*, subject: Subject, target_total: int) -> list[_PickPlan]:
    canonical = subject_canonical_key(subject.slug)
    if not canonical:
        return []
    slots = osym_slots_for_subject(canonical)
    if not slots:
        return []
    scaled = scale_osym_slots(slots, target_total)
    plans = _osym_slots_to_pick_plans(scaled, subject_key=canonical)
    if not _osym_plans_have_pool(plans):
        return []
    return plans


def _osym_plans_for_full_exam(*, target_total: int) -> list[_PickPlan]:
    scaled = scale_osym_slots(OSYM_FULL_EXAM, target_total)
    plans: list[_PickPlan] = []
    for slot in scaled:
        slot_plans = _osym_slots_to_pick_plans([slot], subject_key=slot.subject_key)
        if slot_plans:
            plans.extend(slot_plans)
    if not _osym_plans_have_pool(plans):
        return []
    return plans


def _plan_filters(plan: _PickPlan) -> dict:
    filters: dict = {}
    if plan.topic_id:
        filters["topic_id"] = plan.topic_id
    elif plan.subject_id:
        filters["topic__subject_id"] = plan.subject_id
    elif plan.topic_slugs:
        filters["topic__slug__in"] = plan.topic_slugs
    if plan.subtopic:
        filters["subtopic__iexact"] = plan.subtopic
    return filters


def _osym_plans_have_pool(plans: list[_PickPlan]) -> bool:
    """ÖSYM sırası yalnızca her slot için yeterli havuz varsa devreye girer."""
    if not plans:
        return False
    for plan in plans:
        filters = _plan_filters(plan)
        if not filters:
            return False
        if quality_question_qs(**filters).count() < plan.count:
            return False
    return True


def _subject_slugs_for_key(subject_key: str) -> list[str]:
    return list(SUBJECT_SLUG_ALIASES.get(subject_key, [subject_key]))


def _osym_slots_to_pick_plans(
    slots,
    *,
    subject_key: str,
) -> list[_PickPlan]:
    slugs = _subject_slugs_for_key(subject_key)
    subjects = list(Subject.objects.filter(slug__in=slugs, is_active=True))
    if not subjects:
        return []
    subject_ids = [s.id for s in subjects]
    topic_by_slug = {
        row.slug: row.id
        for row in Topic.objects.filter(subject_id__in=subject_ids, is_active=True)
    }
    plans: list[_PickPlan] = []
    for slot in slots:
        if slot.topic_slugs:
            resolved = [topic_by_slug[slug] for slug in slot.topic_slugs if slug in topic_by_slug]
            if not resolved:
                plans.append(
                    _PickPlan(
                        subject_id=subject_ids[0],
                        topic_slugs=list(slot.topic_slugs),
                        count=slot.count,
                        subtopic=slot.subtopic,
                        scenario_group=slot.scenario_group,
                    )
                )
                continue
            if len(resolved) == 1:
                plans.append(
                    _PickPlan(
                        topic_id=resolved[0],
                        count=slot.count,
                        subtopic=slot.subtopic,
                        scenario_group=slot.scenario_group,
                    )
                )
                continue
            split = _split_count(slot.count, len(resolved))
            for topic_id, count in zip(resolved, split):
                if count > 0:
                    plans.append(
                        _PickPlan(
                            topic_id=topic_id,
                            count=count,
                            subtopic=slot.subtopic,
                            scenario_group=slot.scenario_group,
                        )
                    )
            continue
        plans.append(
            _PickPlan(
                subject_id=subject_ids[0],
                count=slot.count,
                subtopic=slot.subtopic,
                scenario_group=slot.scenario_group,
            )
        )
    return plans


def _split_count(total: int, parts: int) -> list[int]:
    if parts <= 0:
        return []
    base = total // parts
    remainder = total % parts
    return [base + (1 if i < remainder else 0) for i in range(parts)]


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
        filters = _plan_filters(row)
        if not filters:
            continue
        total += quality_question_qs(**filters).count()
    return total


def _pick_questions(
    *,
    plan: _PickPlan,
    state: _GeneratorState,
    rng: random.Random,
) -> list[Question]:
    filters = _plan_filters(plan)
    if not filters:
        raise ExamPackGeneratorError("Geçersiz seçim planı.")

    qs = quality_question_qs(**filters).exclude(id__in=state.used_question_ids)

    if plan.scenario_group:
        picked = _pick_scenario_group(qs, plan.count, rng)
    else:
        pool = list(qs)
        if len(pool) < plan.count:
            raise ExamPackGeneratorError(
                f"Konu havuzu yetersiz: {plan.count} istendi, {len(pool)} uygun soru kaldı. "
                "Aynı soru pakette tekrar kullanılmaz."
            )
        rng.shuffle(pool)
        picked = pool[: plan.count]

    if len(picked) < plan.count:
        label = plan.topic_id or plan.subject_id or "/".join(plan.topic_slugs)
        raise ExamPackGeneratorError(
            f"'{label}' için kaliteli orta soru yetersiz: "
            f"{plan.count} istendi, {len(picked)} uygun soru kaldı. "
            "Aynı soru pakette tekrar kullanılmaz."
        )

    state.used_question_ids.update(q.id for q in picked)
    return picked


def _pick_scenario_group(qs, count: int, rng: random.Random) -> list[Question]:
    scenario_ids = list(
        qs.filter(scenario_id__isnull=False)
        .values("scenario_id")
        .annotate(total=Count("id"))
        .filter(total__gte=count)
        .values_list("scenario_id", flat=True)
    )
    if not scenario_ids:
        return []
    chosen_id = rng.choice(scenario_ids)
    group = list(
        qs.filter(scenario_id=chosen_id).order_by("scenario_order", "id")
    )
    if len(group) < count:
        return []
    return group[:count]


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
