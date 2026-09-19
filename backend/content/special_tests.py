"""Sanal özel testler — konu listesini kirletmeden seçili soruları 20’lik dilimler."""

from __future__ import annotations

from dataclasses import dataclass

from .models import Question
from .test_grouping import order_questions_keeping_scenarios

QUESTIONS_PER_TEST = 20


@dataclass(frozen=True)
class SpecialCategoryDef:
    id: str
    title: str
    subject_slug: str
    test_prefix: str
    """Topic slug filter; empty = subject-wide with extra Q filter."""
    topic_slugs: tuple[str, ...] = ()
    """If True, only questions with a non-empty map_template."""
    require_map_template: bool = False
    """Question boolean field name, e.g. tag_kronoloji."""
    require_flag: str | None = None


CATEGORIES: tuple[SpecialCategoryDef, ...] = (
    SpecialCategoryDef(
        id="haritalarla-cografya",
        title="HARİTALARLA COĞRAFYA",
        subject_slug="cografya",
        test_prefix="special_map_cografya",
        require_map_template=True,
    ),
    SpecialCategoryDef(
        id="tarih-kronoloji",
        title="TARİH KRONOLOJİ",
        subject_slug="tarih",
        test_prefix="special_tarih_kronoloji",
        require_flag="tag_kronoloji",
    ),
    SpecialCategoryDef(
        id="padisahlar-antlasmalar",
        title="PADİŞAHLAR VE ANTLAŞMALAR",
        subject_slug="tarih",
        test_prefix="special_padisah_antlasma",
        require_flag="tag_padisah_antlasma",
    ),
    SpecialCategoryDef(
        id="celdiricisi-guclu",
        title="ÇELDİRİCİSİ GÜÇLÜ SORULAR",
        subject_slug="",
        test_prefix="special_celdirici",
        require_flag="tag_celdirici",
    ),
)

# Geriye dönük sabitler (mobil / testler).
MAP_GEOGRAPHY_ID = CATEGORIES[0].id
MAP_GEOGRAPHY_TITLE = CATEGORIES[0].title
MAP_GEOGRAPHY_SUBJECT = CATEGORIES[0].subject_slug
MAP_GEOGRAPHY_TEST_PREFIX = CATEGORIES[0].test_prefix


def _questions_for(cat: SpecialCategoryDef) -> list[Question]:
    qs = Question.objects.filter(
        is_published=True,
        topic__is_active=True,
        topic__subject__is_active=True,
    ).select_related("topic", "topic__subject", "scenario")
    if cat.subject_slug:
        qs = qs.filter(topic__subject__slug=cat.subject_slug)
    if cat.topic_slugs:
        qs = qs.filter(topic__slug__in=cat.topic_slugs)
    if cat.require_map_template:
        qs = qs.exclude(map_template="")
    if cat.require_flag:
        qs = qs.filter(**{cat.require_flag: True})
    return list(qs.order_by("created_at", "id"))


def map_geography_questions() -> list[Question]:
    return _questions_for(CATEGORIES[0])


def chunk_questions(
    questions: list[Question],
    size: int = QUESTIONS_PER_TEST,
) -> list[list[Question]]:
    if size <= 0:
        return []
    ordered = list(questions)
    chunks: list[list[Question]] = []
    for i in range(0, len(ordered), size):
        part = ordered[i : i + size]
        chunks.append(order_questions_keeping_scenarios(part))
    return chunks


def _category_payload(cat: SpecialCategoryDef) -> dict:
    questions = _questions_for(cat)
    tests = []
    for index, group in enumerate(chunk_questions(questions), start=1):
        tests.append(
            {
                "id": f"{cat.test_prefix}_{index}",
                "title": f"Test {index}",
                "questionCount": len(group),
                "questionIds": [q.public_id for q in group],
            }
        )
    return {
        "id": cat.id,
        "title": cat.title,
        "subjectId": cat.subject_slug,
        "questionCount": len(questions),
        "tests": tests,
    }


def build_special_tests_payload() -> dict:
    return {"categories": [_category_payload(cat) for cat in CATEGORIES]}
