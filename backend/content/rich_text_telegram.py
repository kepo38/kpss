"""Telegram çözüm metni normalizasyonu — sohbet yapıştırma kuralları.

Telegram botundan gelen düz metin + message.entities için ayrı pipeline.
Panel yapıştırması için `rich_text_panel` modülünü kullanın.
"""

from __future__ import annotations

import re

from .ocr import normalize_turkish_text
from .rich_text_common import (
    _utf16_index_to_py,
    _wrap_markdown_node,
    collapse_italic_quote_marker_spaces,
    choose_paste_text,
    is_structured_solution_outline,
    normalize_latex,
    normalize_paste_text,
    normalize_roman_solution_sections,
    repair_inline_glued_bold,
    tighten_markdown_markers,
    repair_vert_groups,
    restore_collapsed_breaks,
    structure_solution_outline,
)

__all__ = [
    "normalize_telegram_solution",
    "restore_collapsed_breaks",
    "structure_solution_outline",
    "telegram_entities_to_markdown",
    "normalize_telegram_latex",
    "repair_vert_groups",
]


def normalize_telegram_latex(text: str) -> str:
    """Telegram LaTeX — ortak `normalize_latex` + vert onarımı."""
    return normalize_latex(repair_vert_groups(text or ""))


def telegram_entities_to_markdown(text: str, entities: list[dict] | None) -> str:
    """Telegram message.entities → panel markdown."""
    if not text or not entities:
        return text
    marks: list[tuple[int, int, str, str]] = []
    for ent in entities:
        ent_type = str(ent.get("type") or "")
        offset = int(ent.get("offset") or 0)
        length = int(ent.get("length") or 0)
        if length <= 0:
            continue
        start = _utf16_index_to_py(text, offset)
        end = _utf16_index_to_py(text, offset + length)
        if start >= end:
            continue
        if ent_type == "bold":
            marks.append((start, end, "**", "**"))
        elif ent_type == "italic":
            marks.append((start, end, "*", "*"))
        elif ent_type == "underline":
            marks.append((start, end, "__", "__"))
        elif ent_type == "strikethrough":
            marks.append((start, end, "~~", "~~"))
        elif ent_type in {"code", "pre"}:
            marks.append((start, end, "`", "`"))
    if not marks:
        return text
    marks.sort(key=lambda item: (item[0], item[1] - item[0]), reverse=True)
    out = text
    for start, end, open_m, close_m in marks:
        segment = out[start:end]
        if not segment.strip():
            continue
        wrapped = _wrap_markdown_node(
            segment,
            bold=open_m == "**",
            italic=open_m == "*",
            underline=open_m == "__",
        )
        out = out[:start] + wrapped + out[end:]
    return out


def normalize_telegram_solution(
    text: str,
    *,
    entities: list[dict] | None = None,
) -> str:
    """Telegram bot çözüm metni → kaydedilecek çözüm metni."""
    raw = (text or "").strip()
    if not raw:
        return ""
    if entities:
        raw = telegram_entities_to_markdown(raw, entities)
    raw = normalize_telegram_latex(raw)
    chosen = choose_paste_text(raw, "")
    if is_structured_solution_outline(chosen):
        return normalize_turkish_text(normalize_paste_text(chosen)).strip()
    chosen = restore_collapsed_breaks(chosen)
    chosen = normalize_roman_solution_sections(chosen)
    chosen = structure_solution_outline(chosen)
    chosen = repair_inline_glued_bold(chosen)
    chosen = tighten_markdown_markers(chosen)
    chosen = collapse_italic_quote_marker_spaces(chosen)
    return normalize_turkish_text(chosen).strip()
