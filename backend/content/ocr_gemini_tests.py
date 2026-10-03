"""Gemini OCR birim testleri."""

from contextlib import contextmanager
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings

from content.ocr import (
    _likely_geometry_question,
    _likely_math_question,
    _needs_gemini_fallback,
    _ocr_result_score,
)
from content.ocr_gemini import (
    _extract_json,
    _generation_config_for_model,
    _retryable,
    gemini_configured,
    repair_json_latex_escapes,
)


@contextmanager
def _patch_tesseract_ocr_text(text: str):
    """ocr_question_image extract_text_with_diagnostics kullanır; sahte PNG için okuma da mock."""
    with (
        patch("content.ocr._read_source_bytes", return_value=(b"x", "image/png")),
        patch(
            "content.ocr.extract_text_with_diagnostics",
            return_value=(text, {"attempted": True, "ok": True}),
        ),
    ):
        yield


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

    def test_json_square_triangle_not_eaten(self):
        # Gemini tek \\square / \\triangle yazarsa JSON \\t = TAB yer
        raw = '{"stem": "$' + chr(92) + 'square 73 + ' + chr(92) + 'triangle 37$"}'
        data = _extract_json(raw)
        self.assertIn("stem", data)
        self.assertIn("\\square", data["stem"])
        self.assertIn("\\triangle", data["stem"])
        self.assertNotIn("\x09", data["stem"])
        broken = "$" + "\x09" + "riangle 37$"
        fixed = repair_json_latex_escapes(broken)
        self.assertIn("\\triangle", fixed)
        self.assertNotIn("\x09", fixed)

    def test_json_begin_array_not_eaten_as_backspace(self):
        # Gemini tek \begin / \end yazarsa JSON \b kaçışı bozar
        raw = '{"soru_metni": "$$\\begin{array}{r}AB8\\\\-16C\\\\ \\hline CA3\\end{array}$$"}'
        data = _extract_json(raw)
        self.assertIn("soru_metni", data)
        self.assertIn("\\begin{array}", data["soru_metni"])
        self.assertIn("\\end{array}", data["soru_metni"])
        self.assertNotIn("\x08", data["soru_metni"])

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

    def test_options_visual_payload_keys(self):
        from content.ocr_gemini import _payload_option_boxes, _payload_options_visual

        self.assertTrue(_payload_options_visual({"optionsVisual": True}))
        self.assertTrue(_payload_options_visual({"gorisel_siklar": "true"}))
        self.assertFalse(_payload_options_visual({"gorisel_siklar": False}))
        boxes = _payload_option_boxes(
            {
                "optionBoxes": {
                    "A": [0.1, 0.5, 0.15, 0.3],
                    "E": [0.8, 0.5, 0.15, 0.3],
                }
            }
        )
        self.assertEqual(set(boxes.keys()), {"A", "E"})
        self.assertAlmostEqual(boxes["A"][0], 0.1)

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
        self.assertEqual(result.solution, "")
        self.assertTrue(result.ok)

    @override_settings(GEMINI_API_KEY="test-key")
    def test_geometry_svg_strips_embedded_photo_and_osym(self):
        """Gemini bazen tarama fotoğrafını <image> olarak gömer; vektör kalmalı."""
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
        dirty_svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80">'
            '<image href="data:image/png;base64,iVBORw0KGgo=" width="100" height="80"/>'
            '<text x="90" y="10">ÖSYM</text>'
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
                return dirty_svg
            return text_json

        with patch("content.ocr_gemini._post_gemini_model", side_effect=fake_post):
            result = ocr_question_image_gemini(b"fake-png-bytes")
        self.assertIn("<polygon", result.figure_svg)
        self.assertNotIn("data:image", result.figure_svg)
        self.assertNotIn("<image", result.figure_svg.lower())
        self.assertNotRegex(result.figure_svg, r"(?i)ösym|osym")
        self.assertEqual(result.solution, "")
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
        self.assertEqual(result.solution, "")
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

    def test_square_triangle_operators_not_geometry(self):
        """□/△ kare-küp sayma operatörü geometri sayılmamalı; çözüm silinmemeli."""
        from content.ocr_gemini import strip_geometry_auto_solution

        stem = (
            r"AB iki basamaklı bir doğal sayı olmak üzere "
            r"$\square AB$ ve $\triangle AB$ ifadeleri "
            r"$\square AB$: Karesi AB'ye eşit ya da AB'den küçük olan "
            r"pozitif tam sayıların sayısı "
            r"$\triangle AB$: Küpü AB'ye eşit ya da AB'den küçük olan "
            r"pozitif tam sayıların sayısı "
            r"biçiminde tanımlanmaktadır. "
            r"$\square 73 + \triangle 37$ ifadesinin değeri kaçtır?"
        )
        opts = {"A": "9", "B": "10", "C": "11", "D": "12", "E": "13"}
        solution = r"$\square 73=8$, $\triangle 37=3$ → $8+3=11$"
        self.assertFalse(_likely_geometry_question(stem, opts, stem))
        # OCR «üçgen ifade» / karesi-küpü metni de geometri değil
        ocr_stem = (
            "AB iki basamaklı bir doğal sayı olmak üzere AB ve AB üçgen ifadeleri "
            "Karesi AB'ye eşit ya da AB'den küçük olan pozitif tam sayıların sayısı "
            "Küpü AB'ye eşit ya da AB'den küçük olan pozitif tam sayıların sayısı "
            "73 + 37 üçgen ifadesinin değeri kaçtır?"
        )
        self.assertFalse(_likely_geometry_question(ocr_stem, opts, ocr_stem))
        # Sahte figure_svg olsa bile operatör sorusunda çözüm korunur
        self.assertEqual(
            strip_geometry_auto_solution(
                stem, opts, "<svg></svg>", solution
            ),
            solution,
        )
        from content.ocr_gemini import _post_process_gemini_payload

        stem2, opts2 = _post_process_gemini_payload(stem, dict(opts), "<svg></svg>")
        self.assertEqual(stem2, stem)
        self.assertEqual(opts2, opts)

    def test_verbal_history_not_geometry_strip(self):
        """Tarih / Yalnız I-II-III sorusu geometri sayılmamalı; çözüm silinmemeli."""
        from content.ocr_gemini import strip_geometry_auto_solution

        stem = (
            "1929 yılında başlayan Büyük Buhran sonrası Türkiye'de "
            "1930'lu yıllarda I. Takrir-i Sükûn Kanunu'nun çıkarılması, "
            "II. Devletçilik uygulamasına geçilmesi, "
            "III. Serbest Cumhuriyet Fırkasının kurulması "
            "gelişmelerinden hangileri gerçekleşmiştir?"
        )
        opts = {
            "A": "Yalnız I",
            "B": "Yalnız II",
            "C": "Yalnız III",
            "D": "I ve II",
            "E": "I, II ve III",
        }
        solution = "**II. Devletçilik:** 1930'larda uygulanmıştır."
        self.assertFalse(_likely_geometry_question(stem, opts, stem))
        self.assertEqual(
            strip_geometry_auto_solution(stem, opts, "", solution),
            solution,
        )

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
        from content.ocr import ocr_question_image

        garbage = (
            "x negatif bir gerçel sayı olmak üzere 40-2 dösym\n"
            "A) 1\nC) __dek__ 2\nD) 2\nE) A"
        )
        with _patch_tesseract_ocr_text(garbage):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertTrue(r.stem)
        self.assertTrue(r.options.get("A"))
        self.assertEqual(r.engine, "tesseract")
        self.assertNotIn("Gemini kullanılamadı", r.error or "")

    def test_math_uses_tesseract_only(self):
        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere f ve g fonksiyonları için\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        with _patch_tesseract_ocr_text(tess):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertEqual(r.engine, "tesseract")
        self.assertEqual(r.options.get("A"), "1")
        self.assertEqual(r.options.get("E"), "21")

    def test_function_composition_repair(self):
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
        with _patch_tesseract_ocr_text(tess):
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
        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere f ve g için\n"
            "g(x) = 2x + a (fog)(x) = 3x - a OSYM "
            "f(1) = 9 olduğuna göre f(9) değeri kaçtır?\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        with _patch_tesseract_ocr_text(tess):
            r = ocr_question_image(b"fake-png-bytes")
        self.assertNotIn("OSYM", r.stem.upper())
        self.assertIn("$g(x) = 2x + a$", r.stem)
        self.assertIn("$(f \\circ g)(x) = 3x - a$", r.stem)
        self.assertLess(r.stem.index("$g(x)"), r.stem.index("$(f"))
        self.assertEqual(r.options["E"], "21")

    def test_equations_separate_lines_with_mid_phrase(self):
        from content.ocr import ocr_question_image

        tess = (
            "a bir gerçel sayı olmak üzere f ve g fonksiyonları için\n"
            "g(x) = 2x\n"
            "(f o g)(x) = 3x - a eşitlikleri veriliyor.\n"
            "f(1) = 9 **olduğuna göre** f(9) **değeri kaçtır**?\n"
            "A) 1\nB) 8\nC) 15\nD) 18\nE) 21\n"
        )
        with _patch_tesseract_ocr_text(tess):
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
            with _patch_tesseract_ocr_text(garbage):
                result = ocr_question_image(b"fake-png-bytes")
        self.assertEqual(result.options["A"], "10")
        self.assertEqual(result.options["B"], "12")
        self.assertEqual(result.options["C"], "14")
        self.assertEqual(result.options["D"], "16")
        self.assertEqual(result.options["E"], "18")

    @override_settings(GEMINI_API_KEY="", GEMINI_API_KEY_PAID="")
    def test_not_configured(self):
        self.assertFalse(gemini_configured())

    @override_settings(GEMINI_API_KEY="test-key")
    def test_configured(self):
        self.assertTrue(gemini_configured())

    @override_settings(GEMINI_API_KEY="", GEMINI_API_KEY_PAID="paid-key")
    def test_configured_with_paid_only(self):
        self.assertTrue(gemini_configured())


class GeminiDeadModelSkipTests(SimpleTestCase):
    def test_dead_model_skipped_after_404(self):
        from content import ocr_gemini as og

        og._DEAD_GEMINI_MODELS.clear()
        og._mark_dead_gemini_model(
            "gemini-2.0-flash",
            RuntimeError("Gemini HTTP 404: no longer available"),
        )
        self.assertIn("gemini-2.0-flash", og._DEAD_GEMINI_MODELS)
        with override_settings(GEMINI_OCR_MODEL="gemini-2.0-flash"):
            cands = og._model_candidates()
        self.assertNotIn("gemini-2.0-flash", cands)
        self.assertTrue(any("flash" in m for m in cands))
        og._DEAD_GEMINI_MODELS.clear()


class GeminiTransientRetryTests(SimpleTestCase):
    def tearDown(self):
        from content import ocr_gemini as og

        og._DEAD_GEMINI_MODELS.clear()
        og._reset_gemini_quota_cooldown_for_tests()

    def test_transient_503_retries_same_model(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._DEAD_GEMINI_MODELS.clear()
        og._reset_gemini_quota_cooldown_for_tests()
        sleeps: list[float] = []
        calls = {"n": 0}

        def fake_post(*args, **kwargs):
            calls["n"] += 1
            if calls["n"] < 3:
                raise RuntimeError('Gemini HTTP 503: UNAVAILABLE')
            return '{"ok": true}'

        with patch.object(og, "_post_gemini_model", side_effect=fake_post):
            with patch.object(og.time, "sleep", side_effect=lambda s: sleeps.append(s)):
                raw = og._post_gemini_model_with_retries(
                    b"img", "image/png", "gemini-3.6-flash"
                )
        self.assertEqual(raw, '{"ok": true}')
        self.assertEqual(calls["n"], 3)
        self.assertEqual(sleeps, [1.5, 3.0])

    def test_404_skips_without_sleep(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._DEAD_GEMINI_MODELS.clear()
        og._reset_gemini_quota_cooldown_for_tests()
        sleeps: list[float] = []

        def fake_post(*args, **kwargs):
            err = RuntimeError(
                'Gemini HTTP 404: {"error": {"code": 404, "message": "no longer available"}}'
            )
            og._mark_dead_gemini_model("gemini-2.5-flash", err)
            raise err

        with patch.object(og, "_post_gemini_model", side_effect=fake_post):
            with patch.object(og.time, "sleep", side_effect=lambda s: sleeps.append(s)):
                with self.assertRaises(RuntimeError):
                    og._post_gemini_model_with_retries(
                        b"img", "image/png", "gemini-2.5-flash"
                    )
        self.assertEqual(sleeps, [])
        self.assertIn("gemini-2.5-flash", og._DEAD_GEMINI_MODELS)

    def test_fallback_order_lite_primary_cascade(self):
        from content import ocr_gemini as og

        self.assertEqual(og._GEMINI_MODEL_FALLBACKS[0], "gemini-3.1-flash-lite")
        self.assertEqual(og._GEMINI_MODEL_FALLBACKS[1], "gemini-2.5-flash-lite")
        self.assertNotIn("gemini-3.8-flash", og._GEMINI_MODEL_FALLBACKS)
        with override_settings(GEMINI_OCR_MODEL="gemini-3.5-flash-lite"):
            self.assertEqual(
                og._model_candidates()[:3],
                [
                    "gemini-3.5-flash-lite",
                    "gemini-3.1-flash-lite",
                    "gemini-2.5-flash-lite",
                ],
            )

    def test_quota_classification(self):
        from content.ocr_gemini import is_gemini_quota_error

        self.assertTrue(
            is_gemini_quota_error(
                'Gemini HTTP 429: {"error":{"status":"RESOURCE_EXHAUSTED",'
                '"message":"generate_content_free_tier quota exceeded"}}'
            )
        )
        self.assertTrue(
            is_gemini_quota_error("Gemini HTTP 429: You exceeded your current quota")
        )
        self.assertFalse(is_gemini_quota_error("Gemini HTTP 503: UNAVAILABLE"))
        self.assertFalse(is_gemini_quota_error("Gemini JSON ayrıştırılamadı."))

    def test_quota_429_early_abort_no_same_model_retry(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._reset_gemini_quota_cooldown_for_tests()
        sleeps: list[float] = []
        calls = {"n": 0}

        def fake_post(*args, **kwargs):
            calls["n"] += 1
            raise RuntimeError(
                'Gemini HTTP 429: {"error":{"code":429,"status":"RESOURCE_EXHAUSTED",'
                '"message":"Quota exceeded for generate_content_free_tier"}}'
            )

        with patch.object(og, "_post_gemini_model", side_effect=fake_post):
            with patch.object(og.time, "sleep", side_effect=lambda s: sleeps.append(s)):
                with self.assertRaises(RuntimeError) as ctx:
                    og._post_gemini_model_with_retries(
                        b"img", "image/png", "gemini-3.6-flash"
                    )
        self.assertEqual(calls["n"], 1)
        self.assertEqual(sleeps, [])
        self.assertTrue(og.is_gemini_quota_error(ctx.exception))
        self.assertTrue(og.gemini_quota_cooldown_active())

    def test_quota_429_no_model_cascade(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._reset_gemini_quota_cooldown_for_tests()
        models_hit: list[str] = []

        def fake_retries(image_bytes, mime, model, prompt="", **kwargs):
            models_hit.append(model)
            raise RuntimeError(
                'Gemini HTTP 429: RESOURCE_EXHAUSTED free_tier generate_content_free_tier'
            )

        with patch.object(og, "_post_gemini_model_with_retries", side_effect=fake_retries):
            with patch.object(
                og, "_model_candidates", return_value=["m1", "m2", "m3"]
            ):
                with self.assertRaises(og.GeminiPostError) as ctx:
                    og._post_gemini(b"img", "image/png")
        self.assertEqual(models_hit, ["m1"])
        self.assertTrue(og.is_gemini_quota_error(ctx.exception))

    def test_quota_cooldown_skips_subsequent_attempts(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._reset_gemini_quota_cooldown_for_tests()
        og._arm_gemini_quota_cooldown()
        calls = {"n": 0}

        def fake_post(*args, **kwargs):
            calls["n"] += 1
            return '{"ok": true}'

        with patch.object(og, "_post_gemini_model", side_effect=fake_post):
            with self.assertRaises(RuntimeError) as ctx:
                og._post_gemini_model_with_retries(
                    b"img", "image/png", "gemini-3.6-flash"
                )
        self.assertEqual(calls["n"], 0)
        self.assertIn("cooldown", str(ctx.exception).lower())
        self.assertTrue(og.is_gemini_quota_error(ctx.exception))
        og._reset_gemini_quota_cooldown_for_tests()

    @override_settings(GEMINI_API_KEY="free-key", GEMINI_API_KEY_PAID="paid-key")
    def test_quota_429_falls_back_to_paid_key(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._reset_gemini_quota_cooldown_for_tests()
        keys_seen: list[str] = []

        def fake_post(*args, **kwargs):
            keys_seen.append(og._current_api_key())
            if og._current_api_key() == "free-key":
                raise RuntimeError(
                    'Gemini HTTP 429: {"error":{"code":429,"status":"RESOURCE_EXHAUSTED",'
                    '"message":"Quota exceeded for generate_content_free_tier"}}'
                )
            return '{"ok": true}'

        with patch.object(og, "_post_gemini_model", side_effect=fake_post):
            raw = og._post_gemini_model_with_retries(
                b"img", "image/png", "gemini-3.6-flash"
            )
        self.assertEqual(raw, '{"ok": true}')
        self.assertEqual(keys_seen, ["free-key", "paid-key"])
        self.assertFalse(og.gemini_quota_cooldown_active())
        og._reset_gemini_quota_cooldown_for_tests()

    @override_settings(GEMINI_API_KEY="free-key", GEMINI_API_KEY_PAID="paid-key")
    def test_paid_quota_429_still_cools_down(self):
        from unittest.mock import patch
        from content import ocr_gemini as og

        og._reset_gemini_quota_cooldown_for_tests()
        calls = {"n": 0}

        def fake_post(*args, **kwargs):
            calls["n"] += 1
            raise RuntimeError(
                'Gemini HTTP 429: {"error":{"code":429,"status":"RESOURCE_EXHAUSTED",'
                '"message":"Quota exceeded for generate_content_free_tier"}}'
            )

        with patch.object(og, "_post_gemini_model", side_effect=fake_post):
            with self.assertRaises(RuntimeError):
                og._post_gemini_model_with_retries(
                    b"img", "image/png", "gemini-3.6-flash"
                )
        self.assertEqual(calls["n"], 2)
        self.assertTrue(og.gemini_quota_cooldown_active())
        og._reset_gemini_quota_cooldown_for_tests()


class Gemini3GenerationConfigTests(SimpleTestCase):
    def test_flash_lite_3x_omits_temperature_and_thinking_budget(self):
        cfg = _generation_config_for_model("gemini-3.5-flash-lite", json_mode=True)
        self.assertEqual(cfg.get("responseMimeType"), "application/json")
        self.assertNotIn("temperature", cfg)
        self.assertEqual(cfg.get("thinkingConfig"), {"thinkingLevel": "minimal"})
        budget = (cfg.get("thinkingConfig") or {}).get("thinkingBudget")
        self.assertIsNone(budget)

    def test_flash_lite_25_keeps_budget_zero(self):
        cfg = _generation_config_for_model("gemini-2.5-flash-lite", json_mode=True)
        self.assertEqual(cfg.get("temperature"), 0.1)
        self.assertEqual(cfg.get("thinkingConfig"), {"thinkingBudget": 0})

    def test_http_400_is_retryable_for_model_cascade(self):
        err = RuntimeError(
            'Gemini HTTP 400: {\n  "error": {\n    "code": 400,\n'
            '    "message": "Request contains an invalid argument.",\n'
            '    "status": "INVALID_ARGUMENT"\n  }\n}'
        )
        self.assertTrue(_retryable(err))
