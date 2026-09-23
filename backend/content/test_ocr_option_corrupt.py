from django.test import SimpleTestCase

from content.ocr import repair_premise_markers, repair_premise_option
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
