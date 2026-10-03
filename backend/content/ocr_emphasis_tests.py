"""OCR vurgu (italik/kalın) temizleme testleri."""

from django.test import SimpleTestCase

from .ocr import sanitize_ocr_emphasis
from .ocr_style import OcrWord, _clear_isolated_italic_flags


class SanitizeOcrEmphasisTests(SimpleTestCase):
    def test_strips_single_isolated_italic(self):
        src = "Osmanlı Devleti'nde *Divan-ı* Hümayun toplantıları yapılırdı."
        out = sanitize_ocr_emphasis(src)
        self.assertNotIn("*Divan-ı*", out)
        self.assertIn("Divan-ı Hümayun", out)

    def test_keeps_bold(self):
        src = "Bu **olağanüstü** durumlarda toplanırdı."
        out = sanitize_ocr_emphasis(src)
        self.assertIn("**olağanüstü**", out)

    def test_keeps_two_italics_on_same_line(self):
        src = "*bir* ve *iki* durum"
        out = sanitize_ocr_emphasis(src)
        self.assertIn("*bir*", out)
        self.assertIn("*iki*", out)


class ClearIsolatedItalicFlagsTests(SimpleTestCase):
    def test_clears_lone_italic_word_on_line(self):
        words = [
            OcrWord(
                text="Divan-ı",
                left=0,
                top=0,
                width=40,
                height=20,
                block=1,
                par=1,
                line=1,
                conf=90.0,
                italic=True,
            ),
            OcrWord(
                text="Hümayun",
                left=50,
                top=0,
                width=60,
                height=20,
                block=1,
                par=1,
                line=1,
                conf=90.0,
            ),
        ]
        _clear_isolated_italic_flags(words)
        self.assertFalse(words[0].italic)
