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
    merge_split_inline_dollar_math,
    normalize_latex,
    normalize_paste_text,
    repair_latex_escapes,
    restore_collapsed_breaks,
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

    def test_merge_split_inline_dollar_math(self):
        src = "$Y\n= 7$"
        out = merge_split_inline_dollar_math(src)
        self.assertEqual(out, "$Y = 7$")
        laid_out = restore_collapsed_breaks(src)
        self.assertIn("$Y = 7$", laid_out)
        self.assertNotIn("\n= 7$", laid_out)

    def test_normalize_latex_merges_split_dollar(self):
        src = "Sonuç: $Y\n= 7$ olur."
        out = normalize_latex(src)
        self.assertIn("$Y = 7$", out)

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

    def test_restore_keeps_glued_roman_numeral_labels(self):
        src = "Buna göre\nI.Fidan,\nII. Gamze,\nIII. Işıl"
        out = restore_collapsed_breaks(src)
        self.assertIn("I. Fidan,", out)
        self.assertNotIn("I.\nFidan", out)

    def test_restore_collapsed_breaks_google_daily_solution_dates(self):
        src = (
            "Çözüm Adımları10.06.2024 Sonu:Tarihi geçmeyen 27 yumurta ertesi güne kalır."
            "Tarihi geçen 6 yumurta çöpe atılır.11.06.2024 Başlangıcı ve Ayrımı:"
            "Güne kalan 27 yumurta ile başlanır."
            r"\(2y = 8 \implies \mathbf{y = 4}\) bulunur.\(x\) Değerinin Bulunması:"
            r"\(3x + y = 22\) denkleminde \(y = 4\) yazılır."
            r"Sonuç:\(x \cdot y = 6 \cdot 4 = \mathbf{24}\) olur:"
        )
        out = restore_collapsed_breaks(normalize_latex(src))
        self.assertIn("Çözüm Adımları\n10.06.2024", out)
        self.assertIn("10.06.2024", out)
        self.assertNotIn("10.06.\n2024", out)
        self.assertIn("Sonu:\nTarihi", out)
        self.assertIn("atılır.\n11.06.2024", out)
        self.assertIn("Başlangıcı ve Ayrımı:\nGüne", out)
        self.assertIn("bulunur.\n", out)
        self.assertIn("Değerinin Bulunması:\n", out)
        self.assertIn("Sonuç:\n", out)

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

    def test_structure_solution_outline_hel_presence_table_paste(self):
        from content.rich_text_common import (
            restore_collapsed_breaks,
            structure_solution_outline,
        )

        src = (
            "💡 Adım Adım Mantıksal ÇözümÖğretmenin seçtiği 3 harfin her bir "
            "ismini tek bir şekilde (kesin olarak) belirleyebilmesi için, bu 3 "
            "harfin isimlerdeki dağılımının (kümelenmesinin) her öğrenci için "
            "tamamen benzersiz (farklı) olması gerekir.Öğrencilerimiz: AYNUR, "
            "GÖZDE, HÜLYA, LEMAN, ZEHRASeçeneklerde yer alan H, E, L harflerinin "
            'bu isimlerde bulunma durumlarını ("Var: 1", "Yok: 0") kodlayarak '
            "bir tablo oluşturalım:ÖğrenciH HarfiE HarfiL HarfiOluşan Benzersiz "
            "Kod (H, E, L)AYNURYok (0)Yok (0)Yok (0)000GÖZDEYok (0)Var (1)Yok (0)"
            "010HÜLYAVar (1)Yok (0)Var (1)101LEMANYok (0)Var (1)Var (1)011ZEHRA"
            "Var (1)Var (1)Yok (0)110Görüldüğü üzere, H, E, L harfleri seçildiğinde "
            "her öğrenci için tamamen farklı bir kod kombinasyonu oluşmaktadır."
        )
        broken = restore_collapsed_breaks(src)
        self.assertIn("Çözüm\nÖğretmenin", broken)
        self.assertIn("gerekir.\nÖğrencilerimiz:", broken)
        self.assertIn("ZEHRA\nSeçeneklerde", broken)
        self.assertIn("Öğrenci\nH Harfi", broken)
        self.assertIn("AYNUR\nYok (0)", broken)
        self.assertIn("000\nGÖZDE", broken)
        self.assertIn("110\nGörüldüğü", broken)
        self.assertNotIn("ÖğrenciH Harfi", broken)

        outlined = structure_solution_outline(broken)
        self.assertIn("**💡 Adım Adım Mantıksal Çözüm**", outlined)
        self.assertIn("**Harf kodu:**", outlined)
        self.assertIn("- **AYNUR:** H yok, E yok, L yok → **000**", outlined)
        self.assertIn("- **GÖZDE:** H yok, E var, L yok → **010**", outlined)
        self.assertIn("- **HÜLYA:** H var, E yok, L var → **101**", outlined)
        self.assertIn("- **LEMAN:** H yok, E var, L var → **011**", outlined)
        self.assertIn("- **ZEHRA:** H var, E var, L yok → **110**", outlined)
        self.assertNotIn("ÖğrenciH", outlined)
        again = structure_solution_outline(outlined)
        self.assertEqual(again.count("- **AYNUR:**"), 1)

        for out in (normalize_telegram_solution(src), normalize_pasted_solution(src)):
            self.assertIn("**Harf kodu:**", out)
            self.assertIn("- **ZEHRA:** H var, E var, L yok → **110**", out)

    def test_structure_solution_outline_ab_two_digit_paste(self):
        from content.rich_text_common import structure_solution_outline

        src = (
            r"Adım Adım Çözüm:İki basamaklı sayımız \(ab\) olsun. Soruda verilen şartlar şunlardır:"
            r"Rakamlar sıfırdan farklı (\(a \neq 0, b \neq 0\))"
            r"Rakamlar birbirinden farklı (\(a \neq b\))"
            r'Son maddede "onlar basamağındaki rakamın birler basamağındaki rakama oranı" bir doğal sayı belirtmektedir. '
            r"Yani \(\frac{a}{b}\) bir tam sayıdır (\(a\), \(b\)'nin katıdır)."
            r"Elde edilen 5 sayıdan 4'ü çift, 1'i tek sayıdır."
            r"Kağıda yazılan 5 sayıyı formülleştirelim:"
            r"Kendisi: \(10a + b\)"
            r"Rakamları toplamı: \(a + b\)"
            r"Rakamları çarpımı: \(a \times b\)"
            r"Rakamları farkının mutlak değeri: \(\vert{}a - b\vert{}\)"
            r"Rakamların oranı: \(\frac{a}{b}\)"
            r"1. Tek/Çift Analizi Yaparak Sayıyı Bulma:"
            r"\(a \times b\) (Rakamlar Çarpımı): Elde edilen 5 sayıdan sadece 1 tanesi tek olduğuna göre, "
            r"bu çarpımın çift olması şarttır."
            r"Şimdi \(\frac{a}{b}\) oranının bir doğal sayı olmasını ve rakamların durumlarını inceleyelim. "
            r"Sayımızın \(62\) olduğunu varsayıp test edelim (\(a=6, b=2\)):"
            r"Kendisi: \(62\) (Çift)"
            r"Rakamları toplamı: \(6 + 2 = 8\) (Çift)"
            r"Rakamları çarpımı: \(6 \times 2 = 12\) (Çift)"
            r"Rakamları farkı: \(\vert{}6 - 2\vert{} = 4\) (Çift)"
            r"Rakamları oranı: \(\frac{6}{2} = 3\) (Tek)"
            r"Görüldüğü gibi \(62\) sayısı için elde edilen değerlerden 4 tanesi çift (62, 8, 12, 4) "
            r"ve tam olarak 1 tanesi tek (3) çıkmaktadır."
            r"2. Kağıttaki Sayıların Toplamını Hesaplama:"
            r"Bulduğumuz bu 5 doğal sayıyı toplayalım:"
            r"\(62 + 8 + 12 + 4 + 3 = \mathbf{105}\)"
        )
        for out in (normalize_telegram_solution(src), normalize_pasted_solution(src)):
            self.assertIn("**Adım Adım Çözüm:**", out)
            self.assertIn("- Rakamlar sıfırdan farklı", out)
            self.assertIn("- Kendisi: $10a + b$", out)
            self.assertIn("- Rakamları toplamı: $a + b$", out)
            self.assertIn(r"\lvert a - b \rvert", out)
            self.assertIn("**1. Tek/Çift Analizi Yaparak Sayıyı Bulma:**", out)
            self.assertIn("**2. Kağıttaki Sayıların Toplamını Hesaplama:**", out)
            self.assertIn("- Kendisi: $62$ (Çift)", out)
            self.assertIn("(Tek)", out)
            self.assertIn("Görüldüğü gibi", out)
            self.assertLess(out.index("(Tek)"), out.index("Görüldüğü gibi"))
            self.assertIn(r"\mathbf{105}", out)
            again = structure_solution_outline(out)
            self.assertEqual(again.count("- Kendisi: $10a + b$"), 1)

    def test_structure_solution_outline_xyz_addition_paste(self):
        src = (
            r"1. Adım: Toplama İşlemini Alt Alta Yazalım"
            r"\(\begin{array}{r@{\quad }c@{\quad }c@{\quad }c}"
            r"5&2&A&\\ +&B&4&3\\ \hline X&Y&Z&\end{array}\)"
            r"Elde edilen \(XYZ\) üç basamaklı sayısının tüm rakamları birbirinden farklı tek sayılar "
            r"(\(1, 3, 5, 7, 9\)) olmak zorundadır."
            r"2. Adım: Onlar Basamağını İnceleyelim"
            r"Onlar basamağındaki işlem: \(2 + 4 = 6\)"
            r"Sonucun tek sayı olması gerektiği için, birler basamağından onlar basamağına kesinlikle 1 elde gelmiştir."
            r"Bu durumda onlar basamağının yeni sonucu: \(2 + 4 + 1 = \mathbf{7}\) olur."
            r"Böylece ortadaki rakamı bulduk: \(Y = 7\)."
            r"3. Adım: Birler Basamağından Elde Gelmesini Sağlayalım"
            r"Birler basamağındaki işlem: \(A + 3\)"
            r"5. Adım: Sonuç ve Kontrol"
            r"Sayıları yerine yazalım: \(528 + 443 = \mathbf{971}\)"
            r"Doğru Seçenek: D"
        )
        for out in (normalize_telegram_solution(src), normalize_pasted_solution(src)):
            self.assertIn("**1. Adım: Toplama İşlemini Alt Alta Yazalım**", out)
            self.assertIn("**2. Adım: Onlar Basamağını İnceleyelim**", out)
            self.assertIn("**3. Adım: Birler Basamağından Elde Gelmesini Sağlayalım**", out)
            self.assertIn("**5. Adım: Sonuç ve Kontrol**", out)
            self.assertIn(r"\begin{array}", out)
            self.assertIn("$$", out)
            self.assertIn("\nElde edilen", out)
            self.assertIn("\nSonucun tek", out)
            self.assertIn("\nBu durumda", out)
            self.assertIn(r"\mathbf{971}", out)


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
