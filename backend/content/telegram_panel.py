"""Panel — Telegram onay kuyrugu yardimcilari (yerel)."""

from __future__ import annotations

from dataclasses import dataclass

from .models import OcrIngestLog, Question

_PLACEHOLDER_STEM = "Aşağıdaki görsele göre cevaplayınız."


@dataclass(frozen=True)
class TelegramOcrFlags:
    partial: bool = False
    formula_missing: bool = False
    char_drift: bool = False
    duplicate_hint: bool = False
    risk_score: int = 0

    @property
    def is_risky(self) -> bool:
        return self.risk_score > 0


@dataclass(frozen=True)
class PendingTelegramRow:
    question: Question
    flags: TelegramOcrFlags


def telegram_question_ocr_flags(question: Question) -> TelegramOcrFlags:
    """Telegram sorusu icin OCR / kalite risk bayraklari."""
    partial = False
    formula_missing = False
    char_drift = False
    duplicate_hint = False
    risk_score = 0

    stem = (question.stem or "").strip()
    if not stem or stem == _PLACEHOLDER_STEM:
        partial = True
        risk_score += 3

    opts = question.options_map()
    filled = sum(
        1 for letter in "ABCDE" if (opts.get(letter) or "").strip() not in ("", "—", "-")
    )
    if filled < 3:
        partial = True
        risk_score += 2

    img_hash = (question.source_image_hash or "").strip()
    if img_hash:
        log = (
            OcrIngestLog.objects.filter(source_image_hash=img_hash)
            .order_by("-created_at")
            .first()
        )
        if log is not None:
            if not log.ok:
                partial = True
                risk_score += 2
            if log.issue_formula_missing:
                formula_missing = True
                risk_score += 1
            if log.issue_char_drift:
                char_drift = True
                risk_score += 1
            if log.duplicate_question_id:
                duplicate_hint = True
                risk_score += 1

    return TelegramOcrFlags(
        partial=partial,
        formula_missing=formula_missing,
        char_drift=char_drift,
        duplicate_hint=duplicate_hint,
        risk_score=risk_score,
    )


def build_pending_telegram_rows(
    questions,
    *,
    filter_key: str = "all",
) -> list[PendingTelegramRow]:
    rows = [
        PendingTelegramRow(question=q, flags=telegram_question_ocr_flags(q))
        for q in questions
    ]
    if filter_key == "risky":
        rows = [row for row in rows if row.flags.is_risky]
    elif filter_key == "ok":
        rows = [row for row in rows if not row.flags.is_risky]
    rows.sort(
        key=lambda row: (
            -row.flags.risk_score,
            -row.question.created_at.timestamp(),
        )
    )
    return rows
