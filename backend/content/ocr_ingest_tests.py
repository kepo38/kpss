"""OCR ingest — Gemini fallback logging ve onarım."""

from unittest.mock import patch

from django.test import SimpleTestCase

from .ocr import OcrQuestionResult
from .ocr_gemini import GeminiSupplementResult, _format_ocr_context
from .ocr_ingest import (
    _apply_gemini_supplement_after_fallback,
    _compose_fallback_log_error,
    _merge_gemini_into_ocr,
    normalize_correct_option,
)
from .ocr_diagnostics import compose_error_message, new_diagnostics


class ComposeFallbackLogErrorTests(SimpleTestCase):
    def test_prefers_gemini_error(self):
        result = OcrQuestionResult(
            stem="x",
            options={"A": "1", "B": "2", "C": "3", "D": "4", "E": "5"},
            raw_text="",
            ok=True,
            error="",
            engine="tesseract",
        )
        msg = _compose_fallback_log_error("Gemini HTTP 404: model not found", result)
        self.assertIn("404", msg)
        self.assertIn("Gemini", msg)

    def test_includes_tesseract_secondary(self):
        result = OcrQuestionResult(
            stem="",
            options={},
            raw_text="",
            ok=False,
            error="tesseract empty",
            engine="tesseract",
        )
        msg = _compose_fallback_log_error("Gemini timeout", result)
        self.assertIn("Gemini timeout", msg)
        self.assertIn("tesseract empty", msg)


class MergeGeminiIntoOcrTests(SimpleTestCase):
    def test_merges_answer_solution_and_stem(self):
        ocr = OcrQuestionResult(
            stem="Eski",
            options={"A": "1", "B": "2", "C": "3", "D": "4", "E": "5"},
            raw_text="",
            ok=True,
            engine="tesseract",
        )
        gemini = OcrQuestionResult(
            stem="Yeni soru metni",
            options={"A": "1", "B": "2", "C": "3", "D": "4", "E": "5"},
            raw_text="",
            ok=True,
            correct_option="C",
            solution="Çözüm metni",
            engine="gemini:gemini-2.0-flash",
        )
        _merge_gemini_into_ocr(ocr, gemini)
        self.assertEqual(normalize_correct_option(ocr.correct_option), "C")
        self.assertEqual(ocr.solution, "Çözüm metni")
        self.assertEqual(ocr.stem, "Yeni soru metni")


class ComposeErrorMessageIntegrationTests(SimpleTestCase):
    def test_fallback_pipeline_summary(self):
        diag = new_diagnostics(pipeline="fallback_success")
        diag["gemini"] = {
            "attempted": True,
            "ok": False,
            "error": "Gemini HTTP 503",
            "attempts": [{"model": "gemini-2.0-flash", "ok": False, "error": "503"}],
        }
        diag["tesseract"] = {"attempted": True, "ok": True, "best": {"lang": "tur", "psm": 6}}
        result = OcrQuestionResult(
            stem="soru",
            options={"A": "1", "B": "2", "C": "3", "D": "4", "E": "5"},
            raw_text="",
            ok=True,
            engine="tesseract",
            diagnostics=diag,
        )
        msg = compose_error_message(diag, _compose_fallback_log_error("", result))
        self.assertIn("fallback_success", msg)
        self.assertIn("503", msg)
        self.assertIn("tesseract_ok", msg)


class GeminiSupplementFallbackTests(SimpleTestCase):
    def test_format_ocr_context(self):
        ctx = _format_ocr_context(
            "Soru kökü?",
            {"A": "1", "B": "2", "C": "3", "D": "4", "E": "5"},
        )
        self.assertIn("Soru kökü?", ctx)
        self.assertIn("C) 3", ctx)

    @patch("content.ocr_gemini.gemini_supplement_answer_solution")
    def test_supplement_fills_answer_and_solution(self, mock_supplement):
        mock_supplement.return_value = GeminiSupplementResult(
            correct_option="C",
            solution="Adım adım çözüm",
            model="gemini-2.0-flash",
            attempts=[{"model": "gemini-2.0-flash", "ok": True, "error": ""}],
            ok=True,
        )
        ocr = OcrQuestionResult(
            stem="Osmanlı'da divan toplantısı nerede yapılırdı?",
            options={
                "A": "İkindi",
                "B": "Sefer",
                "C": "Ayak",
                "D": "Çarşamba",
                "E": "Galebe",
            },
            raw_text="...",
            ok=True,
            engine="tesseract",
        )
        applied, err, meta = _apply_gemini_supplement_after_fallback(
            ocr, b"fake-image", mime="image/jpeg"
        )
        self.assertTrue(applied)
        self.assertEqual(err, "")
        self.assertEqual(normalize_correct_option(ocr.correct_option), "C")
        self.assertEqual(ocr.solution, "Adım adım çözüm")
        self.assertTrue(meta["got_answer"])
        self.assertTrue(meta["got_solution"])
        self.assertEqual(meta["model"], "gemini-2.0-flash")

    @patch("content.ocr_gemini.gemini_supplement_answer_solution")
    def test_supplement_skips_when_already_filled(self, mock_supplement):
        ocr = OcrQuestionResult(
            stem="Soru",
            options={"A": "1", "B": "2", "C": "3", "D": "4", "E": "5"},
            raw_text="",
            ok=True,
            correct_option="B",
            solution="Mevcut çözüm",
            engine="tesseract",
        )
        applied, err, meta = _apply_gemini_supplement_after_fallback(
            ocr, b"fake-image", mime="image/jpeg"
        )
        self.assertFalse(applied)
        self.assertFalse(meta["attempted"])
        mock_supplement.assert_not_called()
