"""Sanal özel testler — konu listesini kirletmeden harita sorularını 20’lik dilimler."""

from __future__ import annotations

from .models import Question
from .test_grouping import order_questions_keeping_scenarios

QUESTIONS_PER_TEST = 20
MAP_GEOGRAPHY_ID = "haritalarla-cografya"
MAP_GEOGRAPHY_TITLE = "HARİTALARLA COĞRAFYA"
MAP_GEOGRAPHY_SUBJECT = "cografya"
MAP_GEOGRAPHY_TEST_PREFIX = "special_map_cografya"


def map_geography_questions() -> list[Question]:
    qs = (
        Question.objects.filter(
            is_published=True,
            topic__is_active=True,
            topic__subject__is_active=True,
            topic__subject__slug=MAP_GEOGRAPHY_SUBJECT,
        )
        .exclude(map_template="")
        .select_related("topic", "topic__subject", "scenario")
        .order_by("created_at", "id")
    )
    return list(qs)


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


def build_special_tests_payload() -> dict:
    questions = map_geography_questions()
    tests = []
    for index, group in enumerate(chunk_questions(questions), start=1):
        tests.append(
            {
                "id": f"{MAP_GEOGRAPHY_TEST_PREFIX}_{index}",
                "title": f"Test {index}",
                "questionCount": len(group),
                "questionIds": [q.public_id for q in group],
            }
        )
    return {
        "categories": [
            {
                "id": MAP_GEOGRAPHY_ID,
                "title": MAP_GEOGRAPHY_TITLE,
                "subjectId": MAP_GEOGRAPHY_SUBJECT,
                "questionCount": len(questions),
                "tests": tests,
            }
        ]
    }
