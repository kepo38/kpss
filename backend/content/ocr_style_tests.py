"""OCR biçim tespiti birim testleri."""

from django.test import SimpleTestCase
from PIL import Image, ImageDraw, ImageFont

from content.ocr_style import (
    OcrWord,
    detect_word_styles,
    words_to_styled_text,
    _wrap_markdown,
)


class OcrStyleUnitTests(SimpleTestCase):
    def test_wrap_combinations(self):
        self.assertEqual(_wrap_markdown("x", True, False, False), "**x**")
        self.assertEqual(_wrap_markdown("x", False, True, False), "*x*")
        self.assertEqual(_wrap_markdown("x", False, False, True), "__x__")
        self.assertEqual(_wrap_markdown("x", True, False, True), "__**x**__")
        self.assertEqual(_wrap_markdown("açmak;", False, False, True), "__açmak__;")
        self.assertEqual(_wrap_markdown("x", False, False, False), "x")

    def test_merge_consecutive_same_style(self):
        words = [
            OcrWord("gönül", 0, 0, 40, 20, 1, 1, 1, 90, underline=True),
            OcrWord("açmak;", 50, 0, 50, 20, 1, 1, 1, 90, underline=True),
            OcrWord("sonra", 120, 0, 40, 20, 1, 1, 1, 90),
        ]
        text = words_to_styled_text(words)
        self.assertEqual(text, "__gönül açmak__; sonra")

    def test_detect_underline_on_synthetic(self):
        img = Image.new("L", (400, 80), 255)
        draw = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype("arial.ttf", 28)
        except OSError:
            font = ImageFont.load_default()
        draw.text((20, 15), "gönül açmak", fill=0, font=font)
        # Alt çizgi
        draw.line((20, 48, 200, 48), fill=0, width=2)
        words = [
            OcrWord("gönül", 20, 15, 80, 35, 1, 1, 1, 90),
            OcrWord("açmak", 110, 15, 90, 35, 1, 1, 1, 90),
            OcrWord("diger", 250, 15, 70, 30, 1, 1, 1, 90),
        ]
        detect_word_styles(img, words)
        self.assertTrue(words[0].underline or words[1].underline)
        self.assertFalse(words[2].underline)
