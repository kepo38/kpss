"""Gemini OCR birim testleri."""

from django.test import SimpleTestCase, override_settings

from content.ocr import (
    _likely_geometry_question,
    _likely_math_question,
    _needs_gemini_fallback,
    _ocr_result_score,
)
from content.ocr_gemini import _extract_json, gemini_configured, repair_json_latex_escapes


class GeminiJsonExtractTests(SimpleTestCase):
    def test_json_frac_single_backslash_repaired(self):
        # Gemini tek \ döndürürse JSON \f → form feed yutar
        raw = '{"soru_metni": "$\\frac{(0,4)^2 + (0,1)^3}{(0,5)^2 - 0,02}$ işleminin sonucu kaçtır?"}'
        data = _extract_json(raw)
        self.assertIn("\\frac", data["soru_metni"])
        self.assertNotIn("$rac{", data["soru_metni"])
        self.assertNotIn("\x0c", data["soru_metni"])

    def test_json_sqrt_and_beta_repaired(self):
        raw = r'{"stem": "$\sqrt{x} + \beta$"}'
        data = _extract_json(raw)
        self.assertIn("\\sqrt", data["stem"])
        self.assertIn("\\beta", data["stem"])

    def test_repair_visible_rac_corruption(self):
        broken = "$rac{(0,4)^2}{(0,5)^2}$"
        fixed = repair_json_latex_escapes(broken)
        self.assertIn("\\frac", fixed)
        self.assertNotIn("$rac{", fixed)

    def test_fence_json(self):
        raw = '```json\n{"stem": "test", "options": {"A": "1"}}\n```'
        data = _extract_json(raw)
        self.assertEqual(data["stem"], "test")
        self.assertEqual(data["options"]["A"], "1")

    def test_bare_json(self):
        raw = '{"stem": "x?", "options": {"A": "-1", "B": "-2"}}'
        data = _extract_json(raw)
        self.assertIn("x?", data["stem"])

    def test_canonical_soru_metni_siklar(self):
        from content.ocr_gemini import _payload_options, _payload_stem

        raw = (
            '{"soru_metni": "Şekle göre x kaçtır?", '
            '"siklar": {"A": "**4**", "B": "6", "C": "8", "D": "10", "E": "12"}}'
        )
        data = _extract_json(raw)
        self.assertEqual(_payload_stem(data), "Şekle göre x kaçtır?")
        opts = _payload_options(data)
        self.assertEqual(opts["A"], "4")
        self.assertEqual(opts["E"], "12")

    def test_siklar_as_list(self):
        from content.ocr_gemini import _payload_options

        opts = _payload_options({"siklar": ["1", "8", "15", "18", "21"]})
        self.assertEqual(opts["A"], "1")
        self.assertEqual(opts["C"], "15")
        self.assertEqual(opts["E"], "21")

    def test_strip_osym_watermark(self):
        from content.ocr import _strip_watermarks

        stem = "eşitlikleri veriliyor ÖSYM $f(1) = 9$"
        self.assertNotIn("ÖSYM", _strip_watermarks(stem).upper())
        self.assertIn("$f(1) = 9$", _strip_watermarks(stem))

    def test_dogru_cevap_and_detayli_cozum(self):
        from content.ocr_gemini import _payload_answer, _payload_solution

        raw = (
            '{"soru_metni": "2+2?", '
            '"siklar": {"A": "3", "B": "4", "C": "5", "D": "6", "E": "7"}, '
            '"dogru_cevap": "B", '
            '"detayli_cozum": "2+2=4 olduğundan cevap B.", '
            '"sekil_kodu": ""}'
        )
        data = _extract_json(raw)
        self.assertEqual(_payload_answer(data), "B")
        self.assertIn("2+2=4", _payload_solution(data))

    def test_dogru_cevap_from_marked_text(self):
        from content.ocr_gemini import _payload_answer

        self.assertEqual(_payload_answer({"dogru_cevap": "C)"}), "C")
        self.assertEqual(_payload_answer({"dogru_cevap": "şık D"}), "D")
        self.assertEqual(_payload_answer({"correct_option": "e"}), "E")
        self.assertEqual(_payload_answer({"dogru_cevap": ""}), "")

    def test_sekil_kodu_svg_extracted(self):
        from content.ocr_gemini import _payload_figure

        raw = (
            '{"soru_metni": "ABC üçgeninde x kaçtır?", '
            '"siklar": {"A": "40", "B": "50", "C": "60", "D": "70", "E": "80"}, '
            '"sekil_kodu": "<svg xmlns=\\"http://www.w3.org/2000/svg\\" viewBox=\\"0 0 100 80\\">'
            '<polygon points=\\"10,70 90,70 10,10\\" fill=\\"none\\" stroke=\\"black\\"/>'
            '<text x=\\"8\\" y=\\"78\\">A</text></svg>"}'
        )
        data = _extract_json(raw)
        fig = _payload_figure(data)
        self.assertIn("<svg", fig)
        self.assertIn("polygon", fig)

    def test_sekil_kodu_rejects_script(self):
        from content.ocr_gemini import _payload_figure

        data = {
            "sekil_kodu": '<svg><script>alert(1)</script><rect x="0" y="0" width="1" height="1"/></svg>'
        }
        self.assertEqual(_payload_figure(data), "")

    def test_repair_geometry_merged_option_a(self):
        from content.ocr_gemini import _repair_geometry_payload

        stem = "ABCD eşkenar dörtgen |AB| = 10 birim |BF| = 4 birim |BE| = x"
        options = {
            "A": "B — 10 birim |BF| — 4 birim |BE| — x Yukarıdaki verilere göre x kaç birimdir?",
            "B": "",
            "C": "",
            "D": "",
            "E": "",
        }
        stem2, opts2 = _repair_geometry_payload(stem, options)
        self.assertIn("Yukarıdaki verilere göre", stem2)

    def test_repair_geometry_garbled_screenshot_options(self):
        from content.ocr_gemini import _repair_geometry_payload

        stem = "ABCD eşkenar dörtgen D CcC E D,C, Edoğrusal"
        options = {
            "A": (
                "etili. > B |AB| — 10 birim |BF| — 4 birim |BE| — x "
                "Yukarıdaki verilere göre x kaç birimdir? A 10"
            ),
            "B": "12 Cc 14",
            "C": "Şık C",
            "D": "16",
            "E": "18",
        }
        stem2, opts2 = _repair_geometry_payload(stem, options)
        self.assertIn("Yukarıdaki verilere göre", stem2)
        self.assertEqual(opts2["A"], "10")
        self.assertEqual(opts2["B"], "12")
        self.assertEqual(opts2["C"], "14")
        self.assertEqual(opts2["D"], "16")
        self.assertEqual(opts2["E"], "18")

    def test_repair_leaves_clean_geometry_options(self):
        from content.ocr_gemini import _repair_geometry_payload

        stem = (
            "ABCD eşkenar dörtgen\n"
            "Yukarıdaki verilere göre x kaç birimdir?"
        )
        options = {"A": "10", "B": "12", "C": "14", "D": "16", "E": "18"}
        stem2, opts2 = _repair_geometry_payload(stem, options)
        self.assertEqual(opts2, options)
        self.assertIn("kaç birimdir", stem2)

    @override_settings(GEMINI_API_KEY="test-key")
    def test_geometry_svg_is_separate_call(self):
        import json as json_lib
        from unittest.mock import patch

        from content.ocr_gemini import ocr_question_image_gemini

        text_json = json_lib.dumps(
            {
                "soru_metni": (
                    "ABCD eşkenar dörtgen\n"
                    "Yukarıdaki verilere göre x kaç birimdir?"
                ),
                "siklar": {
                    "A": "10",
                    "B": "12",
                    "C": "14",
                    "D": "16",
                    "E": "18",
                },
                "dogru_cevap": "C",
                "detayli_cozum": "x=14",
            }
        )
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80">'
            '<polygon points="10,70 90,70 10,10" fill="none" stroke="black"/>'
            '<text x="8" y="78">A</text></svg>'
        )

        def fake_post(
            image_bytes,
            mime,
            model,
            prompt="",
            timeout=45,
            json_mode=True,
        ):
            if not json_mode:
                return svg
            return text_json

        with patch("content.ocr_gemini._post_gemini_model", side_effect=fake_post):
            result = ocr_question_image_gemini(b"fake-png-bytes")
        self.assertEqual(result.options["A"], "10")
        self.assertEqual(result.options["C"], "14")
        self.assertIn("<svg", result.figure_svg)
        self.assertTrue(result.ok)

    @override_settings(GEMINI_API_KEY="test-key")
    def test_geometry_text_survives_svg_failure(self):
        import json as json_lib
        from unittest.mock import patch

        from content.ocr_gemini import ocr_question_image_gemini

        text_json = json_lib.dumps(
            {
                "soru_metni": "ABC üçgeninde x kaç birimdir?",
                "siklar": {
                    "A": "10",
                    "B": "12",
                    "C": "14",
                    "D": "16",
                    "E": "18",
                },
                "dogru_cevap": "A",
                "detayli_cozum": "x=10",
            }
        )

        def fake_post(
            image_bytes,
            mime,
            model,
            prompt="",
            timeout=45,
            json_mode=True,
        ):
            if not json_mode:
                raise RuntimeError("Gemini HTTP 429: quota")
            return text_json

        with patch("content.ocr_gemini._post_gemini_model", side_effect=fake_post):
            result = ocr_question_image_gemini(b"fake-png-bytes")
        self.assertEqual(result.options["E"], "18")
        self.assertEqual(result.figure_svg, "")
        self.assertTrue(result.ok)


class OcrScoreTests(SimpleTestCase):
    def test_garbage_tesseract_penalized(self):
        stem = 'x negatif bir gerçel sayı olmak üzere __4-2__ dosym'
        opts = {"A": "1", "B": "2", "C": "", "D": "", "E": ""}
        score = _ocr_result_score(stem, opts, stem)
        self.assertLess(score, 40)

    def test_garbage_triggers_gemini_fallback(self):
        stem = "x negatif bir gerçel sayı olmak üzere 40-2 dösym 2X—2-x 5"
        opts = {"A": "1", "B": "", "C": "__dek__ 2", "D": "2", "E": "A"}
        self.assertTrue(_needs_gemini_fallback(stem, opts, stem))

    def test_sqrt_ocr_triggers_math_detection(self):
        stem = (
            "x ve y pozitif gerçel sayıları için VxX - VYy - 22 "
            "eşitlikleri veriliyor. Buna göre Yy oranı kaçtır?"
        )
        opts = {"A": "4", "B": "©", "C": ", 8", "D": "2V2", "E": "42"}
        self.assertTrue(_likely_math_question(stem, opts, stem))
        self.assertTrue(_needs_gemini_fallback(stem, opts, stem))
        score = _ocr_result_score(stem, opts, stem)
        self.assertLess(score, 70)

    def test_geometry_triggers_gemini(self):
        stem = (
            "ABCD eşkenar dörtgen. D, C, E doğrusal. "
            "Yukarıdaki verilere göre x kaç birimdir?"
        )
        opts = {"A": "10", "B": "12", "C": "14", "D": "16", "E": "18"}
        self.assertTrue(_likely_geometry_question(stem, opts, stem))
        self.assertTrue(_likely_math_question(stem, opts, stem))
        self.assertTrue(_needs_gemini_fallback(stem, opts, stem))

    def test_good_latex_stem_scores_higher(self):
        stem = (
            "x negatif bir gerçel sayı olmak üzere "
            "$\\frac{4^x-2^x}{2^x-2^{-x}} = 2^x - \\frac{1}{5}$ "
            "olduğuna göre x kaçtır?"
        )
        opts = {
            "A": "-1",
            "B": "-2",
            "C": "-1/2",
            "D": "-3/2",
            "E": "-1/4",
        }
        score = _ocr_result_score(stem, opts, stem)
        self.assertGreaterEqual(score, 80)


    def test_gemini_fail_keeps_tesseract_draft(self):
        from unittest.mock import patch

        from content.ocr import ocr_question_image

        garbage = (
            "x negatif bir gerçel sayı olmak üzere 40-2 dösym\n"
            "A) 1\nC) __dek__ 2\nD) 2\nE) A"
        )
        with patch("content.ocr.extract_text", return_value=garbage):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertTrue(r.stem)
        self.assertTrue(r.options.get("A"))
        self.assertEqual(r.engine, "tesseract")
        self.assertNotIn("Gemini kullanılamadı", r.error or "")

    def test_math_uses_tesseract_only(self):
        from unittest.mock import patch

        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere f ve g fonksiyonları için\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        with patch("content.ocr.extract_text", return_value=tess):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertEqual(r.engine, "tesseract")
        self.assertEqual(r.options.get("A"), "1")
        self.assertEqual(r.options.get("E"), "21")

    def test_function_composition_repair(self):
        from unittest.mock import patch

        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere gerçel sayılar kümesi üzerinde "
            "tanımlı f ve g fonksiyonları için\n"
            "g(x) = 2x + a\n"
            "(f o g)(x) = 3x - a\n"
            "OSYM\n"
            "f(1) = 9 olduğuna göre f(9) değeri kaçtır?\n"
            "A) 1\n"
            "B) 8\n"
            "C) 15\n"
            "D) 18 Ee) 21\n"
        )
        with patch("content.ocr.extract_text", return_value=tess):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertNotIn("OSYM", r.stem.upper())
        self.assertNotIn("osym", r.stem.lower())
        self.assertIn("$g(x) = 2x + a$", r.stem)
        self.assertIn("$(f \\circ g)(x) = 3x - a$", r.stem)
        self.assertLess(
            r.stem.index("$g(x)"),
            r.stem.index("$(f"),
        )
        self.assertIn("$", r.stem)
        self.assertIn("f(9)", r.stem)
        self.assertEqual(r.options["D"], "18")
        self.assertEqual(r.options["E"], "21")

    def test_merged_formula_lines_repaired(self):
        from unittest.mock import patch

        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere f ve g için\n"
            "g(x) = 2x + a (fog)(x) = 3x - a OSYM "
            "f(1) = 9 olduğuna göre f(9) değeri kaçtır?\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        with patch("content.ocr.extract_text", return_value=tess):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertNotIn("OSYM", r.stem.upper())
        self.assertIn("$g(x) = 2x + a$", r.stem)
        self.assertIn("$(f \\circ g)(x) = 3x - a$", r.stem)
        self.assertLess(r.stem.index("$g(x)"), r.stem.index("$(f"))
        self.assertEqual(r.options["E"], "21")

    def test_equations_separate_lines_with_mid_phrase(self):
        from unittest.mock import patch

        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere f ve g fonksiyonları için\n"
            "g(x) = 2x\n"
            "(f o g)(x) = 3x - a eşitlikleri veriliyor.\n"
            "f(1) = 9 **olduğuna göre** f(9) **değeri kaçtır**?\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        with patch("content.ocr.extract_text", return_value=tess):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertIn("$g(x) = 2x + a$", r.stem)
        self.assertIn("$(f \\circ g)(x) = 3x - a$", r.stem)
        self.assertIn("eşitlikleri veriliyor", r.stem)
        self.assertNotIn("**", r.stem)
        self.assertNotIn("eşitlikleri veriliyor.$", r.stem)
        self.assertLess(r.stem.index("$g(x)"), r.stem.index("$(f"))
        self.assertLess(r.stem.index("$(f"), r.stem.index("eşitlikleri"))

    def test_partial_stem_recovers_from_garbled_raw(self):
        from content.ocr import _repair_math_stem

        stem = (
            "a bir gerçel sayı olmak üzere gerçel sayılar kümesi üzerinde "
            "tanımlı f ve g fonksiyonları için\n\n"
            "$g(x) = 2x + a$\n\n"
            "$f(1) = 9$ olduğuna göre $f(9)$ değeri kaçtır?"
        )
        raw = (
            "a bir gerçel sayı olmak üzere f ve g fonksiyonları için\n"
            "g(x) = 2x | a\n"
            "(fo glx) 3x | a\n"
            "eşitlikleri veriliyor.\n"
            "f(1) = 9 olduğuna göre f(9) değeri kaçtır?\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        out = _repair_math_stem(stem, raw)
        self.assertIn("$g(x) = 2x + a$", out)
        self.assertIn("$(f \\circ g)(x) = 3x - a$", out)
        self.assertIn("eşitlikleri veriliyor", out)
        self.assertNotIn("|", out)

    def test_clean_option_keeps_signed_and_formula(self):
        from content.ocr import _clean_option_body

        self.assertEqual(_clean_option_body("-1"), "-1")
        self.assertEqual(_clean_option_body("$-1/2$"), "$-1/2$")
        self.assertIn("f(x)", _clean_option_body("$f(x)$"))

    def test_tesseract_geometry_options_repaired(self):
        from unittest.mock import patch

        from content.ocr import ocr_question_image

        garbage = (
            "ABCD eşkenar dörtgen D CcC E\n"
            "A) etili |AB| 10 birim Yukarıdaki verilere göre x kaç birimdir? A 10\n"
            "B) 12 Cc 14\n"
            "C) Şık C\n"
            "D) 16\n"
            "E) 18\n"
        )
        with override_settings(GEMINI_API_KEY=""):
            with patch("content.ocr.extract_text", return_value=garbage):
                result = ocr_question_image(b"fake-png-bytes")
        self.assertEqual(result.options["A"], "10")
        self.assertEqual(result.options["B"], "12")
        self.assertEqual(result.options["C"], "14")
        self.assertEqual(result.options["D"], "16")
        self.assertEqual(result.options["E"], "18")

    @override_settings(GEMINI_API_KEY="")
    def test_not_configured(self):
        self.assertFalse(gemini_configured())

    @override_settings(GEMINI_API_KEY="test-key")
    def test_configured(self):
        self.assertTrue(gemini_configured())
