from django.test import SimpleTestCase, TestCase

from content.models import Question, Subject, TelegramBotSession, Topic
from content.rich_text_panel import normalize_pasted_solution
from content.rich_text_telegram import (
    normalize_telegram_solution,
    restore_collapsed_breaks,
    telegram_entities_to_markdown,
)
from content.rich_text_common import (
    choose_paste_text,
    html_to_markdown,
    normalize_latex,
    normalize_paste_text,
    repair_latex_escapes,
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

    def test_telegram_vert_group_becomes_lvert(self):
        src = (
            r"Verilenlere göre, \(\vert{a - c\vert} = b\) ve "
            r"\(\vert{c - a\vert} = b\) olur."
        )
        out = normalize_telegram_solution(src)
        self.assertIn(r"\lvert a - c \rvert", out)
        self.assertIn(r"\lvert c - a \rvert", out)
        self.assertIn("$", out)
        self.assertNotIn(r"\vert{", out)

    def test_repair_latex_escapes(self):
        src = "$rac{1}{2}$"
        self.assertIn(r"\frac", repair_latex_escapes(src))

    def test_restore_collapsed_breaks_after_math(self):
        src = "Sonuç ($a^b \\equiv a$).Verilen ifade"
        out = restore_collapsed_breaks(src)
        self.assertIn(").\nVerilen", out)

    def test_restore_collapsed_breaks_google_solution_paste(self):
        from content.rich_text_common import normalize_latex

        src = (
            "📊 Adım Adım Net Matematiksel GösterimKitabın Tamamı: 300 sayfa"
            r"İlk 3 Gün Toplamı: \(300 \times \frac{3}{5} = \mathbf{180}\) sayfa."
            r"4. Gün Okunan: \(300 - 180 = \mathbf{120}\) sayfa."
            "İlk İki Gün Toplamı (1. Gün + 2. Gün): 4. gün okunan sayfa sayısı (120), "
            r"ilk iki günün \(\frac{5}{6}\)'sına eşit olduğuna göre;"
            r"\(120=(\text{1.\ Gün}+\text{2.\ Gün})\times \frac{5}{6}"
            r"\implies \text{1.\ Gün}+\text{2.\ Gün}=\mathbf{144}\)"
            "3. Gün Okunan: İlk 3 günün toplamından (180), ilk iki günün toplamını "
            r"(144) çıkarırsak;\(180-144=\mathbf{36}\)"
        )
        out = restore_collapsed_breaks(normalize_latex(src))
        self.assertIn("Gösterim\nKitabın", out)
        self.assertIn("sayfa\nİlk 3 Gün", out)
        self.assertIn("sayfa.\n4. Gün", out)
        self.assertIn("göre;\n$", out)
        self.assertIn("çıkarırsak;\n$", out)
        self.assertIn("$\n3. Gün Okunan", out)
        panel = normalize_pasted_solution(src)
        self.assertIn("\n", panel)
        self.assertIn(r"\frac", panel)

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

    def test_inline_dollar_math_not_split_by_restore(self):
        src = "Taban alanı $Toplam = 5$ olarak bulunur."
        out = restore_collapsed_breaks(normalize_latex(src))
        self.assertIn("$Toplam = 5$", out)
        self.assertNotIn("$\nToplam", out)

    def test_multiline_paren_collapses_to_inline_dollar(self):
        src = "Buradan \\(x = 5\n+ 3\\) bulunur."
        out = normalize_latex(src)
        self.assertIn("$x = 5 + 3$", out)

    def test_restore_does_not_split_units_and_brands(self):
        src = "Değer 5A akım, pH değeri 7, iPhone modeli ve 3D görüntü."
        out = restore_collapsed_breaks(src)
        self.assertIn("5A akım", out)
        self.assertIn("pH değeri", out)
        self.assertIn("iPhone modeli", out)
        self.assertIn("3D görüntü", out)
        self.assertNotIn("5\nA", out)
        self.assertNotIn("p\nH", out)
        self.assertNotIn("i\nPhone", out)
        self.assertNotIn("3\nD", out)

    def test_telegram_pipeline_preserves_inline_math(self):
        src = r"Sonuç \(300 \times \frac{3}{5} = \mathbf{180}\) sayfa."
        out = normalize_telegram_solution(src)
        self.assertIn(r"\frac", out)
        self.assertIn("$300", out)
        self.assertNotIn("$\n300", out)

    def test_structure_solution_outline_google_logic_paste(self):
        from content.rich_text_common import structure_solution_outline

        src = (
            "💡 Adım Adım ÇözümKural Özeti:"
            "Tüm öğrenciler başlangıçta oturuyor."
            "Söylenen harf isminde varsa durum değiştirir."
            "Öğretmen sırasıyla A, B ve C harflerini birer kez söylüyor."
            "Bir öğrencinin son durumda ayakta kalması gerekir."
            "Şimdi seçenekleri kontrol edelim:"
            "A) AYBERK:"
            "A var (Kalktı), B var (Otuttu), C yok."
            r"Toplam değişim: 2 kez \(\rightarrow \) Oturuyor."
            "B) BERKCAN:"
            "A var (Kalktı), B var (Otuttu), C var (Kalktı)."
            r"Toplam değişim: 3 kez \(\rightarrow \) 🧍 AYAKTA."
            "C) CEYDA:"
            "A var (Kalktı), B yok, C var (Otuttu)."
            r"Toplam değişim: 2 kez \(\rightarrow \) Oturuyor."
        )
        tg = normalize_telegram_solution(src)
        panel = normalize_pasted_solution(src)
        for out in (tg, panel):
            self.assertIn("**💡 Adım Adım Çözüm**", out)
            self.assertIn("**Kural Özeti:**", out)
            self.assertIn("- Tüm öğrenciler başlangıçta oturuyor.", out)
            self.assertIn("- **A) AYBERK:**", out)
            self.assertIn("  - A var (Kalktı), B var (Otuttu), C yok.", out)
            self.assertIn("- **B) BERKCAN:**", out)
            self.assertIn("**AYAKTA**", out)
            self.assertIn("- **C) CEYDA:**", out)
            # Idempotent
            again = structure_solution_outline(out)
            self.assertEqual(again.count("- **A) AYBERK:**"), 1)
            self.assertEqual(again.count("- **B) BERKCAN:**"), 1)

    def test_structure_solution_outline_candle_secenegi_paste(self):
        from content.rich_text_common import (
            restore_collapsed_breaks,
            structure_solution_outline,
        )
        from content.rich_text_panel import normalize_pasted_solution
        from content.rich_text_telegram import normalize_telegram_solution

        src = (
            "Beş mumu sadece 2 hamlede kısadan uzuna sıralayabilmek için, "
            "başlangıçta en az 3 mumun kendi aralarında zaten doğru sırada "
            "(artan sırada) duruyor olması gerekir. Geriye kalan 2 mum "
            "aralardan çekilip doğru yerlerine taşınarak sıralama "
            "tamamlanır.Mum boylarını en kısadan en uzuna 1, 2, 3, 4, 5 "
            "sayılarıyla kodlayarak seçenekleri inceleyelim:"
            "A Seçeneği: Dizilim 2 - 3 - 5 - 4 - 1 şeklindedir."
            "2 - 3 - 4 üçlüsü zaten sıralıdır. (2 hamlede yapılabilir)"
            "B Seçeneği: Dizilim 3 - 1 - 4 - 5 - 2 şeklindedir."
            "1 - 4 - 5 üçlüsü zaten sıralıdır. (2 hamlede yapılabilir)"
            "D Seçeneği: Dizilim 3 - 1 - 5 - 4 - 2 şeklindedir."
            "Küçükten büyüğe sıralı hiçbir üçlü grup yoktur."
        )
        broken = restore_collapsed_breaks(src)
        self.assertIn("\nA Seçeneği:", broken)
        self.assertIn("\nB Seçeneği:", broken)
        outlined = structure_solution_outline(broken)
        self.assertIn("- **A Seçeneği:**", outlined)
        self.assertIn("- **B Seçeneği:**", outlined)
        self.assertIn("- **D Seçeneği:**", outlined)
        self.assertIn("  - Dizilim 2 - 3 - 5 - 4 - 1", outlined)
        self.assertIn("  - Küçükten büyüğe sıralı hiçbir üçlü grup yoktur.", outlined)
        for out in (normalize_telegram_solution(src), normalize_pasted_solution(src)):
            self.assertIn("- **A Seçeneği:**", out)
            self.assertIn("- **B Seçeneği:**", out)


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
