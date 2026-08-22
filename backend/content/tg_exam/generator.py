"""TG deneme soru üretici — ExamPack / TopicTest ile karışmaz."""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Any

from django.db.models import Q

from content.models import Question, Subject

from .cooldown import (
    COOLDOWN_DIFFICULTIES,
    TG_EXAM_COOLDOWN_EXAM_COUNT,
    cooldown_excluded_public_ids,
)
from .distribution import DEFAULT_TG_EXAM_DISTRIBUTION, SUBJECT_SLUG_ALIASES


class TgExamGeneratorError(Exception):
    """TG havuz yetersiz veya dağılım hatalı."""


# Geriye dönük isim (panel importları).
ExamGeneratorError = TgExamGeneratorError


@dataclass
class _PickSlot:
    subject_slugs: list[str]
    subtopic: str = ""
    count: int = 1


@dataclass
class _GeneratorState:
    used_public_ids: set[str] = field(default_factory=set)
    slots: list[_PickSlot] = field(default_factory=list)
    cooldown_excluded: set[str] = field(default_factory=set)
    cooldown_relax: int = TG_EXAM_COOLDOWN_EXAM_COUNT


class TgExamGeneratorService:
    """QuestionBank'ten oransal dağılıma göre TG deneme soruları üretir."""

    def __init__(
        self,
        distribution: dict[str, Any] | None = None,
        *,
        kpss_type: str = "lisans",
        exclude_exam_id: int | None = None,
        seed: int | None = None,
    ) -> None:
        self.distribution = distribution or DEFAULT_TG_EXAM_DISTRIBUTION
        self.kpss_type = kpss_type
        self.exclude_exam_id = exclude_exam_id
        self.rng = random.Random(seed)

    def generate(self, *, exclude_public_ids: set[str] | None = None) -> list[str]:
        cooldown_excluded = cooldown_excluded_public_ids(
            kpss_type=self.kpss_type,
            exclude_exam_id=self.exclude_exam_id,
        )
        state = _GeneratorState(
            used_public_ids=set(exclude_public_ids or ()),
            cooldown_excluded=cooldown_excluded,
        )
        plans = self._build_pick_plans()
        question_ids: list[str] = []

        for plan in plans:
            picked = self._pick_for_slot(plan, state)
            question_ids.extend(q.public_id for q in picked)
            state.slots.append(plan)

        return question_ids

    def replace_at_index(
        self,
        question_ids: list[str],
        index: int,
        *,
        distribution: dict[str, Any] | None = None,
    ) -> list[str]:
        if index < 0 or index >= len(question_ids):
            raise TgExamGeneratorError("Geçersiz soru indeksi.")

        old_id = question_ids[index]
        dist = distribution or self.distribution
        service = TgExamGeneratorService(
            dist,
            kpss_type=self.kpss_type,
            exclude_exam_id=self.exclude_exam_id,
            seed=self.rng.randint(0, 2**31 - 1),
        )
        plans = service._build_pick_plans()
        if index >= len(plans):
            raise TgExamGeneratorError("Dağılım planı soru sayısıyla uyuşmuyor.")

        exclude = set(question_ids) - {old_id}
        cooldown_excluded = cooldown_excluded_public_ids(
            kpss_type=self.kpss_type,
            exclude_exam_id=self.exclude_exam_id,
        )
        state = _GeneratorState(
            used_public_ids=exclude,
            cooldown_excluded=cooldown_excluded,
        )
        picked = service._pick_for_slot(plans[index], state)
        if not picked:
            raise TgExamGeneratorError("Yedek soru bulunamadı.")

        updated = list(question_ids)
        updated[index] = picked[0].public_id
        return updated

    def replace_by_question(
        self,
        question_ids: list[str],
        old_public_id: str,
        *,
        distribution: dict[str, Any] | None = None,
    ) -> list[str]:
        try:
            index = question_ids.index(old_public_id)
        except ValueError as exc:
            raise TgExamGeneratorError("Soru bu denemede bulunamadı.") from exc
        return self.replace_at_index(
            question_ids,
            index,
            distribution=distribution,
        )

    def slot_count(self) -> int:
        return sum(slot.count for slot in self._build_pick_plans())

    def _build_pick_plans(self) -> list[_PickSlot]:
        plans: list[_PickSlot] = []
        for key, spec in self.distribution.items():
            plans.extend(self._plans_for_entry(key, spec))
        return plans

    def _plans_for_entry(self, key: str, spec: Any) -> list[_PickSlot]:
        if isinstance(spec, int):
            slugs = self._resolve_subject_slugs(key, None)
            return [_PickSlot(subject_slugs=slugs, count=spec)]

        if not isinstance(spec, dict):
            raise TgExamGeneratorError(f"Geçersiz dağılım girdisi: {key!r}")

        slugs = self._resolve_subject_slugs(key, spec.get("subject_slugs"))
        tags: dict[str, int] = dict(spec.get("tags") or {})
        total = int(spec.get("total") or 0)

        if tags:
            plans: list[_PickSlot] = []
            tagged_total = sum(tags.values())
            for subtopic, count in tags.items():
                if count <= 0:
                    continue
                plans.append(
                    _PickSlot(
                        subject_slugs=slugs,
                        subtopic=str(subtopic).strip(),
                        count=int(count),
                    )
                )
            remainder = total - tagged_total if total else 0
            if remainder > 0:
                plans.append(_PickSlot(subject_slugs=slugs, count=remainder))
            elif total and tagged_total != total:
                raise TgExamGeneratorError(
                    f"{key}: tag toplamı ({tagged_total}) total ({total}) ile uyuşmuyor."
                )
            return plans

        if total <= 0:
            raise TgExamGeneratorError(f"{key}: soru sayısı tanımlı değil.")
        return [_PickSlot(subject_slugs=slugs, count=total)]

    def _resolve_subject_slugs(
        self,
        key: str,
        override: list[str] | None,
    ) -> list[str]:
        if override:
            slugs = [str(s).strip() for s in override if str(s).strip()]
        else:
            slugs = list(SUBJECT_SLUG_ALIASES.get(key, [key]))

        existing = set(
            Subject.objects.filter(slug__in=slugs, is_active=True).values_list(
                "slug", flat=True
            )
        )
        resolved = [s for s in slugs if s in existing]
        if not resolved:
            fallback = Subject.objects.filter(
                Q(slug=key) | Q(slug__startswith=f"{key}_"),
                is_active=True,
            ).values_list("slug", flat=True)
            resolved = list(fallback)
        if not resolved:
            raise TgExamGeneratorError(
                f"'{key}' için aktif ders bulunamadı (slug: {', '.join(slugs)})."
            )
        return resolved

    def _apply_cooldown(self, qs, *, relax_to: int):
        if relax_to <= 0:
            return qs
        excluded = cooldown_excluded_public_ids(
            kpss_type=self.kpss_type,
            exclude_exam_id=self.exclude_exam_id,
            last_n_exams=relax_to,
        )
        return qs.exclude(
            public_id__in=excluded,
            difficulty__in=COOLDOWN_DIFFICULTIES,
        )

    def _pick_for_slot(
        self,
        plan: _PickSlot,
        state: _GeneratorState,
    ) -> list[Question]:
        if plan.count <= 0:
            return []

        base_qs = Question.objects.filter(
            is_published=True,
            topic__is_active=True,
            topic__subject__is_active=True,
            topic__subject__slug__in=plan.subject_slugs,
        ).exclude(public_id__in=state.used_public_ids)

        if plan.subtopic:
            base_qs = base_qs.filter(subtopic__iexact=plan.subtopic)

        label = plan.subtopic or "/".join(plan.subject_slugs)
        picked: list[Question] = []
        pool: list[Question] = []

        for relax in range(state.cooldown_relax, -1, -1):
            qs = self._apply_cooldown(base_qs, relax_to=relax)
            pool = list(qs.select_related("topic", "topic__subject"))
            if len(pool) >= plan.count:
                self.rng.shuffle(pool)
                picked = pool[: plan.count]
                break

        if len(picked) < plan.count:
            raise TgExamGeneratorError(
                f"'{label}' için yeterli soru yok: "
                f"{plan.count} istendi, cooldown sonrası {len(pool)} uygun soru kaldı. "
                f"(Son {TG_EXAM_COOLDOWN_EXAM_COUNT} TG denemesindeki kolay/orta sorular hariç.)"
            )

        state.used_public_ids.update(q.public_id for q in picked)
        return picked


ExamGeneratorService = TgExamGeneratorService


def generate_tg_exam_questions(
    distribution: dict[str, Any] | None = None,
    *,
    kpss_type: str = "lisans",
    exclude_exam_id: int | None = None,
    seed: int | None = None,
) -> list[str]:
    return TgExamGeneratorService(
        distribution,
        kpss_type=kpss_type,
        exclude_exam_id=exclude_exam_id,
        seed=seed,
    ).generate()
