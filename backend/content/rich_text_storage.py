"""Kayıt-tek-yol: soru metin alanlarını tek noktadan normalize et.

Panel, OCR ve Telegram kayıt yolları bu modülü kullanmalı; DB'de temiz markdown
saklanır, istemci yalnızca render hazırlığı yapar (``preNormalized``).
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from .rich_text_panel import (
    normalize_pasted_option,
    normalize_pasted_solution,
    normalize_pasted_stem,
)

if TYPE_CHECKING:
    from .models import Question

_OPTION_FIELDS = ("option_a", "option_b", "option_c", "option_d", "option_e")

_CONTENT_FIELDS = ("stem", *_OPTION_FIELDS, "solution")


def normalize_field(field: str, text: str, *, html: str = "") -> str:
    """Tek alan — panel yapıştırma pipeline'ı."""
    key = (field or "solution").strip().lower()
    if key == "solution":
        return normalize_pasted_solution(text, html=html)
    if key == "stem":
        return normalize_pasted_stem(text, html=html)
    if key in _OPTION_FIELDS or key.startswith("option_") or key == "option":
        return normalize_pasted_option(text, html=html)
    return normalize_pasted_option(text, html=html)


def normalize_question_for_storage(question: Question) -> None:
    """Soru metin alanlarını yerinde normalize et (kayıt öncesi)."""
    question.stem = normalize_pasted_stem(question.stem or "")
    for attr in _OPTION_FIELDS:
        setattr(question, attr, normalize_pasted_option(getattr(question, attr) or ""))
    if question.solution:
        question.solution = normalize_pasted_solution(question.solution)


def normalize_telegram_solution_for_storage(
    text: str,
    *,
    entities: list[dict] | None = None,
) -> str:
    """Telegram entity dönüşümü + panel kayıt pipeline'ı (tek yol)."""
    from .rich_text_common import normalize_latex, repair_vert_groups
    from .rich_text_telegram import telegram_entities_to_markdown

    raw = (text or "").strip()
    if not raw:
        return ""
    if entities:
        raw = telegram_entities_to_markdown(raw, entities)
    raw = normalize_latex(repair_vert_groups(raw))
    return normalize_field("solution", raw)


def question_content_changed(question: Question, *, before: dict[str, str]) -> list[str]:
    """Normalize sonrası değişen alan adları."""
    changed: list[str] = []
    for field in _CONTENT_FIELDS:
        if (getattr(question, field) or "") != before.get(field, ""):
            changed.append(field)
    return changed


def snapshot_question_content(question: Question) -> dict[str, str]:
    return {field: getattr(question, field) or "" for field in _CONTENT_FIELDS}


def question_needs_content_normalize(question: Question) -> bool:
    """Normalize sonrası metin değişecek mi? (dry-run / kademeli onarım filtresi)."""
    from .models import Question as QuestionModel

    before = snapshot_question_content(question)
    clone = QuestionModel(
        stem=before["stem"],
        option_a=before["option_a"],
        option_b=before["option_b"],
        option_c=before["option_c"],
        option_d=before["option_d"],
        option_e=before["option_e"],
        solution=before["solution"],
    )
    normalize_question_for_storage(clone)
    return bool(question_content_changed(clone, before=before))


__all__ = [
    "normalize_field",
    "normalize_question_for_storage",
    "normalize_telegram_solution_for_storage",
    "question_content_changed",
    "question_needs_content_normalize",
    "snapshot_question_content",
]
