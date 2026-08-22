"""Görsel → OCR → Question kaydı (panel ve Telegram ortak)."""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from typing import BinaryIO

from django.core.files.base import ContentFile

from .embeddings import refresh_question_embedding
from .models import OcrIngestLog, Question, Topic
from .ocr import ocr_question_image, strip_option_emphasis
from .ocr_gemini import gemini_configured, ocr_question_image_gemini
from .question_fingerprint import (
    content_fingerprint,
    find_duplicate_question,
    image_fingerprint,
    image_phash,
    stem_fingerprint,
)
from .special_question_tags import apply_auto_tags
from .svg_sanitize import extract_svg, is_safe_svg
from .topic_classifier import classify_topic_from_ocr


def _sanitize_figure_svg(raw: str) -> str:
    code = extract_svg(raw or "")
    return code if is_safe_svg(code) else ""


def _detect_formula_missing(stem: str, options: dict[str, str], raw_text: str) -> bool:
    text = f"{stem}\n" + "\n".join((options or {}).values())
    raw = raw_text or ""
    raw_has_math = bool(
        re.search(r"[=^√]|\\frac|\\sqrt|\d+\s*/\s*\d+|\d+\s*-\s*\d+\s*/\s*\d+", raw)
    )
    has_latex = "$" in text or r"\frac" in text or r"\sqrt" in text
    return raw_has_math and not has_latex


def _detect_char_drift(stem: str, options: dict[str, str], raw_text: str) -> bool:
    text = f"{stem}\n{raw_text}\n" + "\n".join((options or {}).values())
    if "�" in text:
        return True
    return bool(re.search(r"\?{2,}|[<>]{2,}|[|/\\-]{4,}", text))


def _new_public_id(prefix: str = "q") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:10]}"


def _normalize_options(raw: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for letter in "ABCDE":
        val = strip_option_emphasis((raw.get(letter) or "").strip())
        out[letter] = val or "—"
    return out


@dataclass
class IngestQuestionResult:
    ok: bool
    question: Question | None = None
    error: str = ""
    duplicate: Question | None = None
    duplicate_match: str = ""
    partial: bool = False
    engine: str = ""
    topic_auto_detected: bool = False


def _run_ocr(image: BinaryIO, *, mime: str = "image/jpeg") -> tuple[object, str, str, bool, bool]:
    gemini_attempted = False
    gemini_failed = False
    if hasattr(image, "seek"):
        image.seek(0)
    img_hash = image_fingerprint(image)
    if hasattr(image, "seek"):
        image.seek(0)
    img_phash = image_phash(image)
    if hasattr(image, "seek"):
        image.seek(0)

    if gemini_configured():
        gemini_attempted = True
        img_bytes = image.read()
        ocr = ocr_question_image_gemini(img_bytes, mime)
        if not ocr.ok:
            gemini_failed = True
            if hasattr(image, "seek"):
                image.seek(0)
            ocr = ocr_question_image(image)
    else:
        ocr = ocr_question_image(image)

    if hasattr(image, "seek"):
        image.seek(0)
    return ocr, img_hash, img_phash, gemini_attempted, gemini_failed


def _log_ingest(
    *,
    topic: Topic | None,
    image_path: str,
    source_image_hash: str,
    source_image_phash: str,
    result,
    duplicate_question: Question | None = None,
    duplicate_match: str = "",
    status: str | None = None,
) -> None:
    try:
        stem = (getattr(result, "stem", "") or "") if result is not None else ""
        options = (getattr(result, "options", {}) or {}) if result is not None else {}
        raw_text = (getattr(result, "raw_text", "") or "") if result is not None else ""
        ok = bool(getattr(result, "ok", False)) if result is not None else False
        engine = (getattr(result, "engine", "") or "") if result is not None else ""
        used_model = ""
        if engine.startswith("gemini:"):
            used_model = engine.split(":", 1)[1]
            engine = "gemini"
        computed_status = status or (
            OcrIngestLog.STATUS_SUCCESS if ok else OcrIngestLog.STATUS_FAILED
        )
        OcrIngestLog.objects.create(
            image_path=image_path or "",
            source_image_hash=source_image_hash or "",
            source_image_phash=source_image_phash or "",
            engine=engine,
            used_model=used_model,
            status=computed_status,
            topic=topic,
            duplicate_question=duplicate_question,
            duplicate_match=duplicate_match or "",
            ok=ok,
            error_message=(getattr(result, "error", "") or "") if result else "",
            raw_response=raw_text,
            stem=stem,
            options=options if isinstance(options, dict) else {},
            raw_text=raw_text,
            issue_formula_missing=_detect_formula_missing(stem, options, raw_text),
            issue_char_drift=_detect_char_drift(stem, options, raw_text),
        )
    except Exception:
        return


def ingest_question_from_image(
    image: BinaryIO,
    *,
    topic: Topic,
    filename: str = "upload.jpg",
    mime: str = "image/jpeg",
    publish: bool = False,
    submission_source: str = Question.SUBMISSION_SOURCE_TELEGRAM,
    telegram_chat_id: int | None = None,
    telegram_message_id: int | None = None,
    telegram_file_unique_id: str = "",
    allow_duplicate: bool = True,
    auto_classify_topic: bool = False,
) -> IngestQuestionResult:
    try:
        ocr, img_hash, img_phash, gemini_attempted, gemini_failed = _run_ocr(
            image, mime=mime
        )
    except Exception as exc:  # noqa: BLE001
        _log_ingest(
            topic=topic,
            image_path=filename,
            source_image_hash="",
            source_image_phash="",
            result=None,
            status=OcrIngestLog.STATUS_FAILED,
        )
        return IngestQuestionResult(ok=False, error=f"OCR hatası: {exc}")

    hard_fail = (not ocr.ok) and not (
        (ocr.stem or "").strip() or (ocr.raw_text or "").strip()
    )
    if hard_fail:
        _log_ingest(
            topic=topic,
            image_path=filename,
            source_image_hash=img_hash,
            source_image_phash=img_phash,
            result=ocr,
            status=OcrIngestLog.STATUS_FAILED,
        )
        return IngestQuestionResult(
            ok=False,
            error=ocr.error or "Görselden metin okunamadı.",
        )

    stem = (ocr.stem or "").strip() or "Aşağıdaki görsele göre cevaplayınız."
    opts = _normalize_options(ocr.options or {})
    figure_svg = _sanitize_figure_svg(getattr(ocr, "figure_svg", "") or "")
    correct_option = getattr(ocr, "correct_option", "") or "A"
    if correct_option not in "ABCDE":
        correct_option = "A"
    solution = (getattr(ocr, "solution", "") or "").strip()

    topic_auto_detected = False
    if auto_classify_topic:
        classified = classify_topic_from_ocr(
            stem,
            opts,
            getattr(ocr, "raw_text", "") or "",
            topic_slug_hint=getattr(ocr, "topic_slug", "") or "",
            subject_slug_hint=getattr(ocr, "subject_slug", "") or "",
            fallback=topic,
        )
        if classified is not None and classified.source != "fallback":
            topic = classified.topic
            topic_auto_detected = True

    c_hash = content_fingerprint(
        stem,
        opts["A"],
        opts["B"],
        opts["C"],
        opts["D"],
        opts["E"],
    )
    s_hash = stem_fingerprint(stem)
    dup, match = find_duplicate_question(
        content_hash=c_hash,
        stem_hash=s_hash,
        image_hash=img_hash,
        image_phash_hex=img_phash,
        require_options=any(v != "—" for v in opts.values()),
        stem=stem,
        option_a=opts["A"],
        option_b=opts["B"],
        option_c=opts["C"],
        option_d=opts["D"],
        option_e=opts["E"],
    )
    _log_ingest(
        topic=topic,
        image_path=filename,
        source_image_hash=img_hash,
        source_image_phash=img_phash,
        result=ocr,
        duplicate_question=dup,
        duplicate_match=match,
        status=(
            OcrIngestLog.STATUS_FALLBACK_SUCCESS
            if gemini_attempted and gemini_failed and ocr.ok
            else OcrIngestLog.STATUS_SUCCESS
        ),
    )
    if dup and not allow_duplicate:
        return IngestQuestionResult(
            ok=False,
            error=f"Benzer soru zaten var: {dup.public_id}",
            duplicate=dup,
            duplicate_match=match,
        )

    question = Question(
        public_id=_new_public_id(),
        topic=topic,
        stem=stem,
        option_a=opts["A"],
        option_b=opts["B"],
        option_c=opts["C"],
        option_d=opts["D"],
        option_e=opts["E"],
        correct_option=correct_option,
        solution=solution,
        figure_svg=figure_svg,
        source_image_hash=img_hash,
        source_image_phash=img_phash,
        is_published=publish,
        submission_source=submission_source,
        telegram_chat_id=telegram_chat_id,
        telegram_message_id=telegram_message_id,
        telegram_file_unique_id=(telegram_file_unique_id or "").strip(),
    )
    apply_auto_tags(question, only_raise=False)
    if hasattr(image, "seek"):
        image.seek(0)
    image_bytes = image.read()
    question.image.save(filename, ContentFile(image_bytes), save=False)
    question.save()
    refresh_question_embedding(question)

    partial = not ocr.ok or not any(
        (ocr.options or {}).get(letter, "").strip() for letter in "ABCDE"
    )
    return IngestQuestionResult(
        ok=True,
        question=question,
        duplicate=dup,
        duplicate_match=match,
        partial=partial,
        engine=getattr(ocr, "engine", "") or "",
        topic_auto_detected=topic_auto_detected,
    )
