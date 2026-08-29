"""Görsel → OCR → Question kaydı (panel ve Telegram ortak)."""

from __future__ import annotations

import io
import re
import uuid
from dataclasses import dataclass
from typing import BinaryIO

from django.core.files.base import ContentFile

from .embeddings import refresh_question_embedding
from .models import OcrIngestLog, Question, Topic
from .ocr import ocr_question_image, strip_option_emphasis
from .ocr_diagnostics import compose_error_message, log_ocr_event, merge_diagnostics, new_diagnostics
from .ocr_gemini import gemini_configured, ocr_question_image_gemini
from .question_fingerprint import (
    content_fingerprint,
    find_duplicate_question,
    image_fingerprint,
    image_phash,
    stem_fingerprint,
)
from .special_question_tags import apply_auto_tags
from .svg_sanitize import sanitize_figure_svg
from .topic_classifier import classify_topic_from_ocr


def _sanitize_figure_svg(raw: str) -> str:
    return sanitize_figure_svg(raw)


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


def normalize_correct_option(raw: str) -> str:
    letter = (raw or "").strip().upper()
    return letter if letter in "ABCDE" else ""


def _normalize_correct_option(raw: str) -> str:
    return normalize_correct_option(raw)


def _compose_fallback_log_error(gemini_error: str, result) -> str:
    """Tesseract fallback satırında ilk Gemini hatasını sakla."""
    primary = (gemini_error or "").strip()
    secondary = (getattr(result, "error", "") or "").strip() if result else ""
    if primary and secondary and secondary not in primary:
        return f"{primary} | tesseract: {secondary}"
    return primary or secondary


def _merge_gemini_into_ocr(ocr, gemini) -> None:
    """Tesseract sonucuna Gemini cevap/çözüm (ve gerekirse metin) ekle."""
    letter = _normalize_correct_option(getattr(gemini, "correct_option", ""))
    if letter:
        ocr.correct_option = letter
    solution = (getattr(gemini, "solution", "") or "").strip()
    if solution:
        ocr.solution = solution
    gemini_stem = (getattr(gemini, "stem", "") or "").strip()
    if gemini_stem:
        ocr.stem = gemini_stem
    gemini_opts = getattr(gemini, "options", None) or {}
    if sum(1 for v in gemini_opts.values() if (v or "").strip()) >= 3:
        ocr.options = gemini_opts
    if getattr(gemini, "figure_svg", ""):
        ocr.figure_svg = gemini.figure_svg


def _apply_gemini_supplement_after_fallback(
    ocr,
    image_bytes: bytes,
    *,
    mime: str = "image/jpeg",
) -> tuple[bool, str, dict[str, object]]:
    """Gemini ilk denemede düştüyse cevap/çözüm için hafif ikinci Gemini çağrısı."""
    meta: dict[str, object] = {
        "attempted": False,
        "ok": False,
        "error": "",
        "model": "",
        "attempts": [],
        "got_answer": False,
        "got_solution": False,
    }
    if not gemini_configured():
        return False, "", meta
    need_answer = not _normalize_correct_option(getattr(ocr, "correct_option", ""))
    need_solution = not (getattr(ocr, "solution", "") or "").strip()
    if not need_answer and not need_solution:
        return False, "", meta

    from .ocr_gemini import gemini_supplement_answer_solution

    meta["attempted"] = True
    supplement = gemini_supplement_answer_solution(
        image_bytes,
        mime,
        stem=(getattr(ocr, "stem", "") or "").strip(),
        options=getattr(ocr, "options", None) or {},
    )
    meta["attempts"] = supplement.attempts
    meta["model"] = supplement.model
    if not supplement.ok:
        meta["error"] = supplement.error or "Gemini tamamlama başarısız"
        return False, str(meta["error"]), meta

    letter = _normalize_correct_option(supplement.correct_option)
    solution = (supplement.solution or "").strip()
    if need_answer and letter:
        ocr.correct_option = letter
        meta["got_answer"] = True
    if need_solution and solution:
        ocr.solution = solution
        meta["got_solution"] = True

    applied = bool(meta["got_answer"] or meta["got_solution"])
    meta["ok"] = applied
    if not applied:
        meta["error"] = "Gemini cevap/çözüm döndürmedi"
        return False, str(meta["error"]), meta
    return True, "", meta


def _attach_ocr_diagnostics(
    ocr,
    *,
    pipeline: str,
    gemini_result=None,
    supplement: dict[str, object] | None = None,
) -> dict:
    """Gemini + Tesseract tanılarını tek JSON'da birleştir."""
    diag = new_diagnostics(pipeline=pipeline)
    if gemini_result is not None and getattr(gemini_result, "diagnostics", None):
        diag = merge_diagnostics(diag, gemini_result.diagnostics)
    if getattr(ocr, "diagnostics", None):
        diag = merge_diagnostics(diag, ocr.diagnostics)
    if supplement:
        slot = diag.setdefault("gemini", {})
        if isinstance(slot, dict):
            slot["supplement"] = supplement
    ocr.diagnostics = diag
    return diag


def _run_ocr(
    image: BinaryIO, *, mime: str = "image/jpeg"
) -> tuple[object, str, str, bool, bool, str]:
    gemini_attempted = False
    gemini_failed = False
    gemini_error = ""
    gemini_result = None
    supplement_diag: dict[str, object] | None = None
    pipeline = "tesseract"
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
        gemini_result = ocr_question_image_gemini(img_bytes, mime)
        if gemini_result.ok:
            ocr = gemini_result
            pipeline = "gemini"
        else:
            gemini_failed = True
            gemini_error = gemini_result.error or "Gemini OCR başarısız"
            if hasattr(image, "seek"):
                image.seek(0)
            ocr = ocr_question_image(image)
            pipeline = "fallback_success" if ocr.ok else "fallback_failed"
            if ocr.ok:
                applied, supplement_err, supplement_diag = (
                    _apply_gemini_supplement_after_fallback(
                        ocr, img_bytes, mime=mime
                    )
                )
                if supplement_err and not applied:
                    gemini_error = (
                        f"{gemini_error} | supplement: {supplement_err}"
                        if gemini_error
                        else supplement_err
                    )
    else:
        ocr = ocr_question_image(image)
        pipeline = "tesseract" if ocr.ok else "tesseract_failed"

    diagnostics = _attach_ocr_diagnostics(
        ocr,
        pipeline=pipeline,
        gemini_result=gemini_result if gemini_failed else None,
        supplement=supplement_diag,
    )
    summarized = compose_error_message(
        diagnostics,
        _compose_fallback_log_error(gemini_error, ocr),
    )
    if summarized:
        gemini_error = summarized

    if hasattr(image, "seek"):
        image.seek(0)
    return ocr, img_hash, img_phash, gemini_attempted, gemini_failed, gemini_error


def _maybe_apply_geometry_overlay(
    ocr,
    image_bytes: bytes,
    *,
    mime: str = "image/jpeg",
) -> None:
    """Tesseract yolu veya kısmi Gemini sonrası — ücretsiz Gemini ile annotasyon."""
    existing = getattr(ocr, "annotated_image_bytes", None)
    if isinstance(existing, (bytes, bytearray)) and existing:
        return
    if not gemini_configured():
        return
    from .ocr import _likely_geometry_question
    from .ocr_gemini import _fetch_geometry_solution_overlay
    from .geometry_overlay_renderer import render_geometry_annotations

    stem = (getattr(ocr, "stem", "") or "").strip()
    options = getattr(ocr, "options", None) or {}
    if not _likely_geometry_question(stem, options, stem):
        return
    overlay_solution, annotations = _fetch_geometry_solution_overlay(
        image_bytes,
        mime,
        stem=stem,
        options=options,
    )
    if overlay_solution:
        current = (getattr(ocr, "solution", "") or "").strip()
        if not current or len(overlay_solution) >= len(current):
            ocr.solution = overlay_solution
    if annotations:
        ocr.geometry_annotations = annotations
        rendered = render_geometry_annotations(image_bytes, annotations)
        if rendered:
            ocr.annotated_image_bytes = rendered


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
    gemini_error: str = "",
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
        diagnostics = getattr(result, "diagnostics", None) if result is not None else {}
        if not isinstance(diagnostics, dict):
            diagnostics = {}
        err = compose_error_message(
            diagnostics or None,
            error_message
            or _compose_fallback_log_error(gemini_error, result)
            or (getattr(result, "error", "") or ""),
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
            error_message=err,
            raw_response=raw_text,
            stem=stem,
            options=options if isinstance(options, dict) else {},
            raw_text=raw_text,
            issue_formula_missing=_detect_formula_missing(stem, options, raw_text),
            issue_char_drift=_detect_char_drift(stem, options, raw_text),
            diagnostics=diagnostics,
        )
        log_ocr_event(
            diagnostics=diagnostics,
            image_path=image_path,
            ok=ok,
            status=computed_status,
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
    if hasattr(image, "seek"):
        image.seek(0)
    source_bytes = image.read()
    buffer = io.BytesIO(source_bytes)
    try:
        ocr, img_hash, img_phash, gemini_attempted, gemini_failed, gemini_error = (
            _run_ocr(buffer, mime=mime)
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

    _maybe_apply_geometry_overlay(ocr, source_bytes, mime=mime)

    stem = (ocr.stem or "").strip() or "Aşağıdaki görsele göre cevaplayınız."
    opts = _normalize_options(ocr.options or {})
    figure_svg = _sanitize_figure_svg(getattr(ocr, "figure_svg", "") or "")
    correct_option = _normalize_correct_option(getattr(ocr, "correct_option", ""))
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
        gemini_error=gemini_error,
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
        stem_image_position=Question.STEM_IMAGE_BELOW,
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
    options_visual = bool(getattr(ocr, "options_visual", False))
    option_crops = getattr(ocr, "option_image_bytes", None) or {}
    if options_visual and option_crops:
        from .option_image_crop import VISUAL_OPTION_PLACEHOLDER

        question.options_are_images = True
        for letter in "ABCDE":
            if not (getattr(question, f"option_{letter.lower()}") or "").strip():
                setattr(question, f"option_{letter.lower()}", VISUAL_OPTION_PLACEHOLDER)
    if not (options_visual and option_crops):
        question.image.save(filename, ContentFile(source_bytes), save=False)
    annotated_bytes = getattr(ocr, "annotated_image_bytes", None)
    if isinstance(annotated_bytes, (bytes, bytearray)) and annotated_bytes:
        question.solution_image.save(
            f"solution_overlay_{question.public_id}.png",
            ContentFile(annotated_bytes),
            save=False,
        )
    question.save()
    if options_visual and option_crops:
        for letter, data in option_crops.items():
            if letter not in "ABCDE" or not data:
                continue
            field_name = f"option_{letter.lower()}_image"
            getattr(question, field_name).save(
                f"opt_{letter}_{question.public_id}.png",
                ContentFile(data),
                save=False,
            )
        question.save(update_fields=[
            "option_a_image",
            "option_b_image",
            "option_c_image",
            "option_d_image",
            "option_e_image",
            "options_are_images",
            "option_a",
            "option_b",
            "option_c",
            "option_d",
            "option_e",
            "updated_at",
        ])
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


def repair_question_with_gemini(
    question: Question,
    *,
    dry_run: bool = False,
) -> dict:
    """Kaynak görselden Gemini ile cevap/çözüm/metin yenile (Tesseract fallback onarımı)."""
    if not question.image:
        return {"ok": False, "error": "Kaynak görsel yok", "pk": question.pk}
    if not gemini_configured():
        return {"ok": False, "error": "GEMINI_API_KEY tanımlı değil", "pk": question.pk}

    try:
        with question.image.open("rb") as handle:
            image_bytes = handle.read()
    except OSError as exc:
        return {"ok": False, "error": f"Görsel okunamadı: {exc}", "pk": question.pk}

    name = (question.image.name or "").lower()
    if name.endswith(".png"):
        mime = "image/png"
    elif name.endswith(".webp"):
        mime = "image/webp"
    elif name.endswith(".gif"):
        mime = "image/gif"
    else:
        mime = "image/jpeg"

    ocr = ocr_question_image_gemini(image_bytes, mime)
    if not ocr.ok:
        return {
            "ok": False,
            "error": ocr.error or "Gemini OCR başarısız",
            "pk": question.pk,
            "public_id": question.public_id,
        }

    updates: dict[str, str] = {}
    stem = (ocr.stem or "").strip()
    if stem:
        updates["stem"] = stem
    opts = _normalize_options(ocr.options or {})
    for letter in "ABCDE":
        val = opts.get(letter, "")
        if val and val != "—":
            updates[f"option_{letter.lower()}"] = val
    letter = _normalize_correct_option(getattr(ocr, "correct_option", ""))
    if letter:
        updates["correct_option"] = letter
    solution = (getattr(ocr, "solution", "") or "").strip()
    if solution:
        updates["solution"] = solution
    figure_svg = _sanitize_figure_svg(getattr(ocr, "figure_svg", "") or "")
    if figure_svg:
        updates["figure_svg"] = figure_svg

    if not dry_run and updates:
        for field, value in updates.items():
            setattr(question, field, value)
        question.save()
        refresh_question_embedding(question)

    return {
        "ok": True,
        "pk": question.pk,
        "public_id": question.public_id,
        "engine": getattr(ocr, "engine", "") or "",
        "updates": updates,
        "dry_run": dry_run,
    }
