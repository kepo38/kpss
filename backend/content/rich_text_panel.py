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
    is_structured_solution_outline,
    _format_named_solution_sections,
    normalize_latex,
    normalize_paste_text,
    normalize_roman_solution_sections,
    repair_latex_escapes,
    restore_collapsed_breaks,
    structure_solution_outline,
)


def normalize_pasted_stem(
    text: str,
    *,
    html: str = "",
) -> str:
    """Panel soru kökü — yapıştırma normalizasyonu (çözüm outline yok)."""
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
    return normalize_turkish_text(normalize_paste_text(chosen)).strip()


def normalize_pasted_option(
    text: str,
    *,
    html: str = "",
) -> str:
    """Panel şık metni — hafif yapıştırma normalizasyonu."""
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
    return normalize_turkish_text(normalize_paste_text(chosen)).strip()


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
    chosen = _format_named_solution_sections(chosen)
    if is_structured_solution_outline(chosen):
        return normalize_turkish_text(chosen).strip()
    chosen = restore_collapsed_breaks(chosen)
    chosen = _format_named_solution_sections(chosen)
    chosen = normalize_roman_solution_sections(chosen)
    chosen = structure_solution_outline(chosen)
    return normalize_turkish_text(chosen).strip()


def normalize_panel_paste_field(
    field: str,
    text: str,
    *,
    html: str = "",
) -> str:
    """Tek giriş — panel yapıştırma alanı (solution/stem/option)."""
    key = (field or "solution").strip().lower()
    if key == "solution":
        return normalize_pasted_solution(text, html=html)
    if key == "stem":
        return normalize_pasted_stem(text, html=html)
    if key == "option" or key.startswith("option_"):
        return normalize_pasted_option(text, html=html)
    return normalize_pasted_option(text, html=html)


__all__ = [
    "choose_paste_text",
    "collapse_bullet_prefixes",
    "collapse_nested_marks",
    "html_clipboard_to_text",
    "html_to_markdown",
    "normalize_latex",
    "normalize_panel_paste_field",
    "normalize_paste_text",
    "normalize_pasted_option",
    "normalize_pasted_solution",
    "normalize_pasted_stem",
    "repair_latex_escapes",
    "restore_collapsed_breaks",
    "structure_solution_outline",
]
