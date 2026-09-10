"""OCR ingest — Gemini fallback logging ve onarım."""

import json
from unittest.mock import MagicMock, patch

from types import SimpleNamespace

from django.test import SimpleTestCase

from .ocr import OcrQuestionResult
from .ocr_gemini import GeminiSupplementResult, _format_ocr_context
from .ocr_ingest import (
    _apply_gemini_supplement_after_fallback,
    _compose_fallback_log_error,
    _count_corrupt_options,
    _merge_gemini_into_ocr,
    _option_is_corrupt,
    _question_needs_gemini_repair,
    coalesce_ocr_options,
    normalize_correct_option,
    panel_form_options,
    question_form_bootstrap,
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

    @patch("content.ocr_gemini.gemini_supplement_answer_solution")
    def test_supplement_fills_missing_options(self, mock_supplement):
        mock_supplement.return_value = GeminiSupplementResult(
            correct_option="B",
            solution="Çözüm",
            model="gemini-2.0-flash",
            attempts=[{"model": "gemini-2.0-flash", "ok": True, "error": ""}],
            ok=True,
            options={
                "A": "Reaya : Halk",
                "B": "Ulema : Din adamları",
                "C": "Tımar : Dirlik",
                "D": "Ocak : Yeniçeri ocağı",
                "E": "Millet : Halk",
            },
        )
        ocr = OcrQuestionResult(
            stem="Tabloya göre hangi eşleştirme yanlıştır?",
            options={"A": "—", "B": "—", "C": "—", "D": "—", "E": "—"},
            raw_text="",
            ok=True,
            correct_option="",
            solution="",
            engine="tesseract",
        )
        applied, err, meta = _apply_gemini_supplement_after_fallback(
            ocr, b"fake-image", mime="image/jpeg"
        )
        self.assertTrue(applied)
        self.assertTrue(meta["got_options"])
        self.assertEqual(ocr.options["B"], "Ulema : Din adamları")
        mock_supplement.assert_called_once()
        self.assertTrue(mock_supplement.call_args.kwargs.get("need_options"))


class PanelFormOptionsTests(SimpleTestCase):
    def test_hydrates_from_stem_when_placeholders(self):
        question = SimpleNamespace(
            stem=(
                "Soru metni burada?\n"
                "A) İkindi Divanı\n"
                "B) Sefer Divanı\n"
                "C) Ayak Divanı\n"
                "D) Çarşamba Divanı\n"
                "E) Galebe Divanı"
            ),
            option_a="—",
            option_b="—",
            option_c="—",
            option_d="—",
            option_e="—",
        )
        opts = panel_form_options(question)
        self.assertEqual(opts["C"], "Ayak Divanı")
        self.assertEqual(opts["A"], "İkindi Divanı")

    def test_keeps_existing_options(self):
        question = SimpleNamespace(
            stem="Soru?",
            option_a="İkindi Divanı",
            option_b="Sefer Divanı",
            option_c="Ayak Divanı",
            option_d="Çarşamba Divanı",
            option_e="Galebe Divanı",
        )
        opts = panel_form_options(question)
        self.assertEqual(opts["C"], "Ayak Divanı")


class CoalesceOcrOptionsTests(SimpleTestCase):
    def test_parses_options_from_stem_when_api_empty(self):
        stem = (
            "1982 Anayasası sorusu?\n"
            "A) Genelkurmay Başkanı\n"
            "B) Cumhurbaşkanı\n"
            "C) Milli Savunma Bakanı\n"
            "D) TBMM Başkanı\n"
            "E) Cumhurbaşkanı Yardımcısı"
        )
        out_stem, opts = coalesce_ocr_options(stem, {}, "")
        self.assertIn("1982 Anayasası", out_stem)
        self.assertNotIn("A)", out_stem)
        self.assertEqual(opts["B"], "Cumhurbaşkanı")
        self.assertEqual(opts["E"], "Cumhurbaşkanı Yardımcısı")

    def test_coalesce_from_json_raw_with_dash_placeholders(self):
        stem = "Tabloya göre hangi eşleştirme yanlıştır?"
        placeholders = {k: "—" for k in "ABCDE"}
        raw = json.dumps(
            {
                "soru_metni": stem,
                "siklar": {
                    "A": "Reaya : Halk",
                    "B": "Ulema : Din adamları",
                    "C": "Tımar : Dirlik",
                    "D": "Ocak : Yeniçeri ocağı",
                    "E": "Millet : Halk",
                },
            },
            ensure_ascii=False,
        )
        _, opts = coalesce_ocr_options(stem, placeholders, raw)
        self.assertEqual(opts["A"], "Reaya : Halk")
        self.assertEqual(opts["D"], "Ocak : Yeniçeri ocağı")


class QuestionFormBootstrapTests(SimpleTestCase):
    def test_bootstrap_includes_options_and_meta(self):
        question = SimpleNamespace(
            stem="Soru?",
            option_a="İkindi Divanı",
            option_b="Sefer Divanı",
            option_c="Ayak Divanı",
            option_d="Çarşamba Divanı",
            option_e="Galebe Divanı",
            solution="Çözüm metni",
            correct_option="C",
        )
        boot = question_form_bootstrap(question)
        self.assertEqual(boot["options"]["C"], "Ayak Divanı")
        self.assertEqual(boot["solution"], "Çözüm metni")
        self.assertEqual(boot["correct_option"], "C")


class CorruptOptionDetectionTests(SimpleTestCase):
    def test_detects_tesseract_roman_pipe_garbage(self):
        self.assertTrue(_option_is_corrupt("Yalnız |"))
        self.assertTrue(_option_is_corrupt("Yalnız ll"))
        self.assertTrue(_option_is_corrupt("| ve ll"))
        self.assertFalse(_option_is_corrupt("Yalnız I"))
        self.assertFalse(_option_is_corrupt("II ve III"))

    def test_detects_ui_junk_in_option(self):
        self.assertTrue(
            _option_is_corrupt("1, Il ve İli Ss o. N oru sorun *& e. ipe Bs")
        )

    def test_count_corrupt_options(self):
        opts = {
            "A": "Yalnız |",
            "B": "Yalnız II",
            "C": "I ve III",
            "D": "II ve III",
            "E": "I, II ve III",
        }
        self.assertEqual(_count_corrupt_options(opts), 1)


class QuestionNeedsGeminiRepairTests(SimpleTestCase):
    def _question(self, **kwargs):
        defaults = {
            "pk": 1,
            "is_published": False,
            "submission_source": "telegram",
            "image": object(),
            "stem": "11:43 Soru: Metin",
            "solution": "",
            "source_image_hash": "abc",
            "option_a": "Yalnız |",
            "option_b": "Yalnız ll",
            "option_c": "| ve ll",
            "option_d": "Il ve İli",
            "option_e": "1, Il ve İli Ss o. N oru",
        }
        defaults.update(kwargs)
        return SimpleNamespace(**defaults)

    @patch("content.ocr_ingest.gemini_configured", return_value=True)
    @patch("content.ocr_ingest._ocr_log_was_tesseract_fallback", return_value=True)
    def test_pending_telegram_with_corrupt_opts(self, *_mocks):
        q = self._question()
        self.assertTrue(_question_needs_gemini_repair(q))

    @patch("content.ocr_ingest.gemini_configured", return_value=True)
    @patch("content.ocr_ingest._ocr_log_was_tesseract_fallback", return_value=True)
    def test_skips_when_published(self, *_mocks):
        q = self._question(is_published=True)
        self.assertFalse(_question_needs_gemini_repair(q))

    @patch("content.ocr_ingest.gemini_configured", return_value=True)
    @patch("content.ocr_ingest._ocr_log_was_tesseract_fallback", return_value=False)
    def test_skips_clean_panel_question(self, *_mocks):
        q = self._question(
            submission_source="",
            stem="Temiz soru metni",
            option_a="Bir",
            option_b="İki",
            option_c="Üç",
            option_d="Dört",
            option_e="Beş",
            solution="Çözüm var",
        )
        self.assertFalse(_question_needs_gemini_repair(q))


class RepairQuestionPreservesSolutionTests(SimpleTestCase):
    def _fake_image(self):
        return SimpleNamespace(
            open=lambda *a, **k: MagicMock(
                __enter__=lambda s: s,
                __exit__=lambda *a: False,
                read=lambda: b"fake",
            ),
            name="questions/x.jpg",
        )

    @patch("content.ocr_ingest.refresh_question_embedding")
    @patch("content.ocr_ingest.normalize_question_for_storage")
    @patch("content.ocr_ingest.ocr_question_image_gemini")
    @patch("content.ocr_ingest.gemini_configured", return_value=True)
    def test_does_not_overwrite_existing_solution(self, _cfg, mock_ocr, _norm, _emb):
        from content.ocr_ingest import repair_question_with_gemini

        mock_ocr.return_value = SimpleNamespace(
            ok=True,
            stem="Yeni stem",
            options={"A": "Bir", "B": "İki", "C": "Üç", "D": "Dört", "E": "Beş"},
            correct_option="B",
            solution="OCR çözüm metni",
            figure_svg="",
            raw_text="",
            engine="gemini",
        )
        question = SimpleNamespace(
            pk=99,
            public_id="q_testpreserve",
            image=self._fake_image(),
            stem="Eski stem",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            correct_option="A",
            solution="Panelde kaydedilmiş çözüm",
            figure_svg="",
            save=MagicMock(),
        )
        result = repair_question_with_gemini(question, dry_run=False)
        self.assertTrue(result.get("ok"))
        self.assertNotIn("solution", result.get("updates") or {})
        self.assertEqual(question.solution, "Panelde kaydedilmiş çözüm")

    @patch("content.ocr_ingest.refresh_question_embedding")
    @patch("content.ocr_ingest.normalize_question_for_storage")
    @patch("content.ocr_ingest.ocr_question_image_gemini")
    @patch("content.ocr_ingest.gemini_configured", return_value=True)
    def test_fills_solution_when_empty(self, _cfg, mock_ocr, _norm, _emb):
        from content.ocr_ingest import repair_question_with_gemini

        mock_ocr.return_value = SimpleNamespace(
            ok=True,
            stem="Yeni stem",
            options={"A": "Bir", "B": "İki", "C": "Üç", "D": "Dört", "E": "Beş"},
            correct_option="B",
            solution="OCR çözüm metni",
            figure_svg="",
            raw_text="",
            engine="gemini",
        )
        question = SimpleNamespace(
            pk=100,
            public_id="q_testfill",
            image=self._fake_image(),
            stem="Eski stem",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            correct_option="A",
            solution="",
            figure_svg="",
            save=MagicMock(),
        )
        result = repair_question_with_gemini(question, dry_run=False)
        self.assertTrue(result.get("ok"))
        self.assertEqual(result.get("updates", {}).get("solution"), "OCR çözüm metni")
