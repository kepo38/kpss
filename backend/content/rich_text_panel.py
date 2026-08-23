"""Panel çözüm metni normalizasyonu — rich-format.js ile uyumlu.

Panelde js-rich textarea yapıştırma kurallarının sunucu tarafı karşılığı.
Telegram için `rich_text_telegram` modülünü kullanın.
"""

from __future__ import annotations

from .ocr import normalize_turkish_text
from .rich_text_common import (
    _HTML_TAG_RE,
    choose_paste_text,
    collapse_bullet_prefixes,
    collapse_nested_marks,
    html_clipboard_to_text,
    html_to_markdown,
    normalize_latex,
    normalize_paste_text,
    repair_latex_escapes,
    restore_collapsed_breaks,
    structure_solution_outline,
)


def normalize_pasted_solution(
    text: str,
    *,
    html: str = "",
) -> str:
    """Panel js-rich yapıştırma → kaydedilecek çözüm metni."""
    raw = (text or "").strip()
    html_src = (html or "").strip()
    if not raw and not html_src:
        return ""
    if _HTML_TAG_RE.search(raw):
        chosen = choose_paste_text(raw, raw)
    elif html_src:
        chosen = choose_paste_text(raw, html_src)
    else:
        chosen = choose_paste_text(raw, "")
    chosen = restore_collapsed_breaks(chosen)
    chosen = structure_solution_outline(chosen)
    return normalize_turkish_text(chosen).strip()


__all__ = [
    "choose_paste_text",
    "collapse_bullet_prefixes",
    "collapse_nested_marks",
    "html_clipboard_to_text",
    "html_to_markdown",
    "normalize_latex",
    "normalize_paste_text",
    "normalize_pasted_solution",
    "repair_latex_escapes",
    "restore_collapsed_breaks",
    "structure_solution_outline",
]
