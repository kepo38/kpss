"""OCR (Gemini / Tesseract) tanılama — log ve OcrIngestLog.diagnostics."""

from __future__ import annotations

import json
import logging
from typing import Any

logger = logging.getLogger("kpss.ocr")

_MAX_ERROR_LEN = 800
_MAX_ATTEMPTS = 24


def _clip(text: str, limit: int = _MAX_ERROR_LEN) -> str:
    s = (text or "").strip()
    if len(s) <= limit:
        return s
    return s[: limit - 3] + "..."


def new_diagnostics(*, pipeline: str = "") -> dict[str, Any]:
    return {
        "pipeline": pipeline,
        "gemini": {
            "configured": False,
            "attempted": False,
            "ok": False,
            "model": "",
            "error": "",
            "attempts": [],
            "supplement": {"attempted": False, "ok": False, "error": ""},
        },
        "tesseract": {
            "attempted": False,
            "ok": False,
            "error": "",
            "best": {},
            "attempts": [],
        },
    }


def merge_diagnostics(base: dict[str, Any] | None, extra: dict[str, Any] | None) -> dict[str, Any]:
    out = dict(base or new_diagnostics())
    if not extra:
        return out
    for key, val in extra.items():
        if key in ("gemini", "tesseract") and isinstance(val, dict):
            slot = out.setdefault(key, {})
            if isinstance(slot, dict):
                slot.update(val)
            continue
        out[key] = val
    return out


def attach_gemini_failure(diag: dict[str, Any], *, error: str, attempts: list[dict[str, Any]]) -> None:
    g = diag.setdefault("gemini", {})
    g["attempted"] = True
    g["ok"] = False
    g["error"] = _clip(error)
    if attempts:
        g["attempts"] = attempts[-_MAX_ATTEMPTS:]


def attach_gemini_success(
    diag: dict[str, Any], *, model: str, attempts: list[dict[str, Any]]
) -> None:
    g = diag.setdefault("gemini", {})
    g["attempted"] = True
    g["ok"] = True
    g["model"] = model
    g["error"] = ""
    if attempts:
        g["attempts"] = attempts[-_MAX_ATTEMPTS:]


def attach_tesseract(diag: dict[str, Any], tesseract_diag: dict[str, Any]) -> None:
    if not tesseract_diag:
        return
    slot = diag.setdefault("tesseract", {})
    slot.update(tesseract_diag)


def summarize_for_error_message(diag: dict[str, Any] | None) -> str:
    """İnsan okunur kısa özet — OcrIngestLog.error_message."""
    if not diag:
        return ""
    parts: list[str] = []
    pipeline = (diag.get("pipeline") or "").strip()
    if pipeline:
        parts.append(f"pipeline={pipeline}")

    gemini = diag.get("gemini") or {}
    if gemini.get("attempted"):
        if gemini.get("ok"):
            parts.append(f"gemini_ok={gemini.get('model') or '?'}")
        else:
            err = _clip(str(gemini.get("error") or ""), 400)
            if err:
                parts.append(f"gemini_fail={err}")
            attempts = gemini.get("attempts") or []
            failed = [a for a in attempts if not a.get("ok")]
            if failed:
                last = failed[-1]
                parts.append(
                    f"gemini_last={last.get('model')}: {_clip(str(last.get('error') or ''), 200)}"
                )
        sup = gemini.get("supplement") or {}
        if sup.get("attempted"):
            if sup.get("ok"):
                parts.append("supplement_ok")
                if sup.get("model"):
                    parts.append(f"supplement_model={sup.get('model')}")
            elif sup.get("error"):
                parts.append(f"supplement_fail={_clip(str(sup['error']), 200)}")

    tess = diag.get("tesseract") or {}
    if tess.get("attempted"):
        if tess.get("ok"):
            best = tess.get("best") or {}
            parts.append(
                "tesseract_ok"
                + (f" lang={best.get('lang')} psm={best.get('psm')}" if best else "")
            )
        elif tess.get("error"):
            parts.append(f"tesseract_fail={_clip(str(tess['error']), 300)}")

    return " | ".join(parts)


def compose_error_message(
    diag: dict[str, Any] | None,
    result_error: str = "",
) -> str:
    summary = summarize_for_error_message(diag)
    secondary = _clip(result_error)
    if summary and secondary and secondary not in summary:
        return f"{summary} | result={secondary}"
    return summary or secondary


def log_ocr_event(
    *,
    diagnostics: dict[str, Any] | None,
    image_path: str = "",
    ok: bool = False,
    status: str = "",
) -> None:
    payload = {
        "ok": ok,
        "status": status,
        "image_path": image_path,
        "diagnostics": diagnostics or {},
    }
    text = json.dumps(payload, ensure_ascii=False, default=str)
    if ok and (diagnostics or {}).get("pipeline") != "fallback_success":
        logger.info("OCR %s", text[:4000])
    elif ok:
        logger.warning("OCR fallback %s", text[:4000])
    else:
        logger.error("OCR failed %s", text[:4000])
