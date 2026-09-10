"""OCR tanılama yardımcıları — birim testleri."""

from django.test import SimpleTestCase

from .ocr_diagnostics import (
    attach_gemini_failure,
    compose_error_message,
    merge_diagnostics,
    new_diagnostics,
    summarize_for_error_message,
)


class OcrDiagnosticsTests(SimpleTestCase):
    def test_summarize_gemini_fail_with_attempts(self):
        diag = new_diagnostics(pipeline="fallback_success")
        attach_gemini_failure(
            diag,
            error="Gemini HTTP 503: UNAVAILABLE",
            attempts=[
                {"model": "gemini-2.0-flash", "ok": False, "error": "HTTP 503"},
                {"model": "gemini-1.5-flash-latest", "ok": False, "error": "HTTP 404"},
            ],
        )
        diag["tesseract"] = {
            "attempted": True,
            "ok": True,
            "best": {"lang": "tur", "psm": 6},
        }
        summary = summarize_for_error_message(diag)
        self.assertIn("pipeline=fallback_success", summary)
        self.assertIn("gemini_fail=", summary)
        self.assertIn("gemini_last=", summary)
        self.assertIn("tesseract_ok", summary)

    def test_compose_error_message_merges_result(self):
        diag = new_diagnostics(pipeline="tesseract_failed")
        diag["tesseract"] = {"attempted": True, "ok": False, "error": "empty OCR"}
        msg = compose_error_message(diag, "Görselden metin okunamadı.")
        self.assertIn("tesseract_fail=", msg)
        self.assertIn("Görselden metin okunamadı", msg)

    def test_merge_diagnostics_nested(self):
        base = new_diagnostics(pipeline="gemini")
        base["gemini"]["model"] = "gemini-2.0-flash"
        extra = {"tesseract": {"attempted": True, "ok": True, "best": {"lang": "tur"}}}
        merged = merge_diagnostics(base, extra)
        self.assertEqual(merged["gemini"]["model"], "gemini-2.0-flash")
        self.assertTrue(merged["tesseract"]["ok"])
