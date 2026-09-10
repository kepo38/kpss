"""Geriye dönük uyumluluk — yeni kod panel/telegram modüllerini doğrudan kullanmalı."""

from .rich_text_common import (
    choose_paste_text,
    collapse_bullet_prefixes,
    collapse_nested_marks,
    has_latex,
    html_clipboard_to_text,
    html_to_markdown,
    latex_score,
    normalize_exam_arrows,
    normalize_latex,
    normalize_markup,
    normalize_paste_text,
    repair_latex_escapes,
    repair_vert_groups,
)
from .rich_text_panel import normalize_pasted_solution
from .rich_text_telegram import (
    normalize_telegram_solution,
    restore_collapsed_breaks,
    telegram_entities_to_markdown,
)

__all__ = [
    "choose_paste_text",
    "collapse_bullet_prefixes",
    "collapse_nested_marks",
    "has_latex",
    "html_clipboard_to_text",
    "html_to_markdown",
    "latex_score",
    "normalize_exam_arrows",
    "normalize_latex",
    "normalize_markup",
    "normalize_paste_text",
    "normalize_pasted_solution",
    "normalize_telegram_solution",
    "repair_latex_escapes",
    "repair_vert_groups",
    "restore_collapsed_breaks",
    "telegram_entities_to_markdown",
]
