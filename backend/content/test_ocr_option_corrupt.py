from django.test import SimpleTestCase

from content.ocr import format_premise_stem, repair_premise_markers, repair_premise_option
from content.ocr_ingest import _option_is_corrupt, finalize_ocr_options_for_panel


class OcrOptionCorruptTests(SimpleTestCase):
    def test_latex_fraction_options_not_corrupt(self):
        for opt in (
            r"$\frac{58}{15}$",
            r"$\frac{68}{25}$",
            r"$$\frac{1}{2}$$",
        ):
            with self.subTest(opt=opt):
                self.assertFalse(_option_is_corrupt(opt))

    def test_ui_junk_still_corrupt(self):
        self.assertTrue(_option_is_corrupt("Yalnız | ve ll"))

    def test_glued_roman_and_bare_label(self):
        self.assertTrue(_option_is_corrupt("YalnızlI"))
        self.assertTrue(_option_is_corrupt("Yalnızlil"))
        self.assertTrue(_option_is_corrupt("B)"))

    def test_repairs_tesseract_premise_options(self):
        cases = {
            "Yalnız lI": "Yalnız II",
            "Yalnızlll": "Yalnız III",
            "İvelil": "I ve II",
            "İlvelli": "II ve III",
            "1,ll ve lll": "I, II ve III",
            "1, İl ve lll": "I, II ve III",
            "Yalnız I": "Yalnız I",
        }
        for raw, expected in cases.items():
            with self.subTest(raw=raw):
                self.assertEqual(repair_premise_option(raw), expected)

    def test_finalize_repairs_before_blanking(self):
        stem = "yıllarda |. Takrir, II. Devletçilik, INI. Fırka"
        opts = {
            "A": "Yalnız lI",
            "B": "Yalnızlll",
            "C": "İvelil",
            "D": "İlvelli",
            "E": "1,ll ve lll",
        }
        stem_out, fixed, corrupt = finalize_ocr_options_for_panel(stem, opts, "")
        self.assertFalse(corrupt)
        self.assertIn("I. Takrir", stem_out)
        self.assertIn("III. Fırka", stem_out)
        self.assertEqual(fixed["A"], "Yalnız II")
        self.assertEqual(fixed["D"], "II ve III")
        self.assertEqual(fixed["E"], "I, II ve III")
        self.assertIn("I. Takrir", repair_premise_markers("yıllarda Il. Takrir"))
        self.assertIn("III. Serbest", repair_premise_markers("(11. Serbest"))


class FormatPremiseStemTests(SimpleTestCase):
    def test_comma_glued_premises_become_multiline(self):
        stem = (
            "Türkiye'de 1930'lu yıllarda I. Takrir-i Sükûn Kanunu'nun çıkarılması, "
            "II. Devletçilik uygulamasına geçilmesi, III. Serbest Cumhuriyet "
            "Fırkasının kurulması\n\ngelişmelerinden hangileri yaşanmıştır?"
        )
        out = format_premise_stem(stem)
        self.assertIn("yıllarda;", out)
        self.assertIn("\nI. Takrir", out)
        self.assertIn("\nII. Devletçilik", out)
        self.assertIn("\nIII. Serbest", out)
        self.assertIn("\n\ngelişmelerinden hangileri", out)
        # Onermeler tek paragrafta kalmasin
        self.assertNotIn(", II.", out)

    def test_il_marker_repaired_then_split(self):
        stem = "1930'lu yıllarda Il. Takrir A, II. Devlet B, III. Serbest C gelişmelerinden hangileri?"
        out = format_premise_stem(stem)
        self.assertTrue(out.startswith("1930'lu yıllarda;"))
        self.assertIn("\nI. Takrir A", out)
        self.assertIn("\nII. Devlet B", out)
        self.assertIn("\nIII. Serbest C", out)
        self.assertIn("gelişmelerinden hangileri?", out)

    def test_single_marker_unchanged(self):
        stem = "Metinde yalnızca I. madde geciyor hangisi dogrudur?"
        self.assertEqual(format_premise_stem(stem), stem)
