from django.test import SimpleTestCase

from content.ocr_ingest import _option_is_corrupt


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
