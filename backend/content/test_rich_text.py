from django.test import SimpleTestCase, TestCase

from content.models import Question, Subject, TelegramBotSession, Topic
from content.rich_text import (
    choose_paste_text,
    html_to_markdown,
    normalize_latex,
    normalize_pasted_solution,
    normalize_paste_text,
    repair_latex_escapes,
    restore_collapsed_breaks,
    telegram_entities_to_markdown,
)
from content.telegram_conversation import try_handle_conversation


class RichTextNormalizationTests(SimpleTestCase):
    def test_html_bold_and_bullets(self):
        html = (
            "<p><strong>A) Karahanlılar</strong></p>"
            "<ul><li><b>Neden Çeldirici?</b> Metin parçası.</li>"
            "<li><b>KPSS Hap Bilgi:</b> Özet cümle.</li></ul>"
        )
        out = normalize_pasted_solution("", html=html)
        self.assertIn("**A) Karahanlılar**", out)
        self.assertIn("**Neden Çeldirici?**", out)
        self.assertIn("**KPSS Hap Bilgi:**", out)
        self.assertIn("- ", out)

    def test_latex_bracket_to_dollar(self):
        src = r"Denklem \[ x^2 + 1 \] ve inline \( a+b \)."
        out = normalize_paste_text(src)
        self.assertIn("$$x^2 + 1$$", out)
        self.assertIn("$a+b$", out)

    def test_repair_latex_escapes(self):
        src = "$rac{1}{2}$"
        self.assertIn(r"\frac", repair_latex_escapes(src))

    def test_restore_collapsed_breaks_after_math(self):
        src = "Sonuç ($a^b \\equiv a$).Verilen ifade"
        out = restore_collapsed_breaks(src)
        self.assertIn(").\nVerilen", out)

    def test_choose_paste_prefers_plain_when_it_has_latex(self):
        plain = r"Çözüm: $\frac{1}{2}$ ve devam"
        html = "<p>Çözüm: 1/2 ve devam</p>"
        out = choose_paste_text(plain, html)
        self.assertIn(r"\frac", out)

    def test_telegram_entities_to_markdown(self):
        text = "Başlık ve açıklama"
        entities = [
            {"type": "bold", "offset": 0, "length": 6},
            {"type": "underline", "offset": 10, "length": 8},
        ]
        out = telegram_entities_to_markdown(text, entities)
        self.assertIn("**Başlık**", out)
        self.assertIn("__açıklama__", out)

    def test_html_u_tag_converted(self):
        raw = "<p><strong>KPSS Hap Bilgi:</strong> <u>Önemli cümle</u></p>"
        out = html_to_markdown(raw)
        self.assertIn("**KPSS Hap Bilgi:**", out)
        self.assertIn("__Önemli cümle__", out)

    def test_exam_arrow_normalization(self):
        out = normalize_pasted_solution("A -> B sonucu")
        self.assertIn("→", out)


class TelegramSolutionNormalizationIntegrationTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="tarih", name="Tarih")
        topic = Topic.objects.create(
            subject=subject,
            slug="turk_tarih",
            name="Türk Tarihi",
        )
        self.question = Question.objects.create(
            topic=topic,
            public_id="q_norm_test",
            stem="Soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
        )
        TelegramBotSession.objects.create(
            telegram_user_id=42,
            chat_id=1001,
            step=TelegramBotSession.STEP_SOLUTION_TEXT,
            question=self.question,
        )

    def test_conversation_saves_normalized_solution(self):
        pasted = (
            "A) Karahanlılar\n"
            "- **Neden Çeldirici?** Gazneliler ile birlikte hareket etmişlerdir.\n"
            "- **KPSS Hap Bilgi:** Karahanlılar ilk Müslüman Türk devletidir."
        )
        reply = try_handle_conversation(42, pasted)
        self.assertIsNotNone(reply)
        self.question.refresh_from_db()
        self.assertIn("**Neden Çeldirici?**", self.question.solution)
        self.assertIn("**KPSS Hap Bilgi:**", self.question.solution)
        self.assertNotIn("<strong>", self.question.solution)
        self.assertNotIn("<u>", self.question.solution)

    def test_conversation_normalizes_latex(self):
        pasted = r"Sonuç \[ \frac{1}{2} \] olarak bulunur."
        try_handle_conversation(42, pasted)
        self.question.refresh_from_db()
        self.assertIn("$$", self.question.solution)
        self.assertIn(r"\frac", self.question.solution)
