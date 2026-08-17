from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, TestCase
from PIL import Image, ImageDraw

from content.models import Question
from content.ocr import parse_question_text, strip_option_emphasis


class OptionParseTests(SimpleTestCase):
    def test_classic_a_to_e(self):
        raw = """
Türkiye Cumhuriyeti hangi yılda kurulmuştur?
A) 1920
B) 1923
C) 1919
D) 1938
E) 1924
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertIn("Türkiye", stem)
        self.assertEqual(opts["A"], "1920")
        self.assertEqual(opts["B"], "1923")
        self.assertEqual(opts["C"], "1919")
        self.assertEqual(opts["D"], "1938")
        self.assertEqual(opts["E"], "1924")

    def test_ocr_c_as_six_and_orphan_parens(self):
        """Gerçek OCR: C)→6, satır kırığı ') istediği', D/E ayırıcısız."""
        raw = """
Bilge Kağan'ın Çin'de olduğu gibi ülkesinde de savunma
amacıyla şehirleri surlarla çevirtmek, hisarlar yaptırmak
istemesine Tonyukuk itiraz etmiştir.
Buna göre aşağıdakilerden hangisi söylenemez?
A) Hükümdarın mutlak otoritesini kaybettiği
B) Göktürklerin nüfusunun Çinlilerden az olduğu
6   Bilge Kağan'ın saldırılara karşı ülkesini korumak

) istediği
D   Yaşam şekillerinin savaşa hazırlıklı olmalarında

) etkisinin olduğu
E   Savaş koşullarını içinde bulundukları şartların

) belirlediği
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertIn("söylenemez", stem)
        self.assertEqual(opts["A"], "Hükümdarın mutlak otoritesini kaybettiği")
        self.assertEqual(opts["B"], "Göktürklerin nüfusunun Çinlilerden az olduğu")
        self.assertEqual(
            opts["C"],
            "Bilge Kağan'ın saldırılara karşı ülkesini korumak istediği",
        )
        self.assertEqual(
            opts["D"],
            "Yaşam şekillerinin savaşa hazırlıklı olmalarında etkisinin olduğu",
        )
        self.assertEqual(
            opts["E"],
            "Savaş koşullarını içinde bulundukları şartların belirlediği",
        )
        self.assertNotIn("Hükümdarın", stem)
        self.assertNotIn("Yaşam şekillerinin", stem)

    def test_option_a_prefix_before_marker(self):
        """OCR: A) metninin başı işaretten önceki satırda kalır."""
        raw = """
Nizamülmülk, Siyasetname adlı eserinde bir kimsenin
mahkemeye gelmek istememesi hâlinde ne kadar
yüksek makam sahibi olursa olsun onun zorla
mahkemeye getirilmesi gerektiğini ifade etmiştir.
Buna göre Nizamülmülk'ün aşağıdakilerden
hangisini gerçekleştirmeyi hedeflediği söylenemez?
Toplumun, ülkedeki adalet sistemine olan güvenini
A)  artırmayı
B   Farklı dil, din ve ırk mensuplarını ortak hukuk
) sisteminde birleştirmeyi
c   Mahkemelerde toplumsal statüden kaynaklanan
) ayrıcalıkları kaldırmayı
D   Mahkemelerde adil karar alınması için ortam
)  hazırlamayı
E   Yargılama sürecinde devlet gücünü zorlayıcı olarak
)  kullanmayı
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertIn("söylenemez?", stem)
        self.assertNotIn("Toplumun", stem)
        self.assertEqual(
            opts["A"],
            "Toplumun, ülkedeki adalet sistemine olan güvenini artırmayı",
        )
        self.assertIn("ortak hukuk", opts["B"])
        self.assertIn("ayrıcalıkları", opts["C"])

    def test_option_a_after_question_mark_same_line(self):
        raw = """
Metin metin metin.
Buna göre hangisi söylenemez? Adaleti güçlendirmeyi
A) istemeyi
B) bozmayı
C) yok saymayı
D) ertelemeyi
E) unutmayı
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertTrue(stem.endswith("söylenemez?"))
        self.assertNotIn("Adaleti", stem)
        self.assertEqual(opts["A"], "Adaleti güçlendirmeyi istemeyi")

    def test_passage_after_question_stays_in_stem(self):
        """Soru üstte, olay+maddeler ortada, şıklar altta — pasaj A'ya kaçmasın."""
        raw = """
Buna göre I. Fidan, II. Gamze, III. Işıl adlı çocuklardan
hangileri tahterevallide oynamış olabilir?
Bir grup çocuk parkta oynamaktadır. Tahterevalli, kaydırak
ve salıncak bulunmaktadır. Aşağıdakiler bilinmektedir:
• Fidan kaydırakta oynamıştır.
• Gamze tahterevallide oynamamıştır.
• Işıl salıncakta oynamıştır.
• Tahterevallide oynayan en az iki çocuktur.
• Kaydırakta oynayan çocuk salıncakta da oynamıştır.
• Salıncakta oynayan çocuk tahterevallide oynamamıştır.
A) Yalnız I
B) Yalnız II
C) Yalnız III
D) I ve II
E) I ve III
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertIn("tahterevallide oynamış olabilir?", stem)
        self.assertIn("Bir grup çocuk parkta", stem)
        self.assertIn("Fidan kaydırakta", stem)
        self.assertIn("Salıncakta oynayan", stem)
        self.assertEqual(opts["A"], "Yalnız I")
        self.assertEqual(opts["B"], "Yalnız II")
        self.assertEqual(opts["C"], "Yalnız III")
        self.assertEqual(opts["D"], "I ve II")
        self.assertEqual(opts["E"], "I ve III")
        self.assertNotIn("parkta", opts["A"])
        self.assertNotIn("Fidan", opts["A"])

    def test_marker_lines_merged_without_auto_format(self):
        """Madde işareti satırları gömülür (düz metin OCR örneği)."""
        raw = """
Türkçeye boşuna gönül dili demiyorlar. Gönle dair
o kadar çok söz var ki dilimizde. Örneğin insanın
iç sıkıntısını gidermek anlamında gönül açmak;
|
birini hoş bir söz ya da davranışla sevindirmek
gönül okşamak; üzülmek rahatsızlık duymak
ll
anlamında gönlüne dokunmak; bir şeye istek
NI

duymamak, istememek durumunu anlatmak için
gönül yıkmak; gücenmeyi, darılmayı anlatmak için

IV
gönül koymak ve daha niceleri... Gönlümüze hoş

V
gelene de hoş gelmeyene de gönlü ortak etmişiz.
Yukarıda numaralanmış sözlerden hangisi parçadaki
açıklamasıyla uyuşmamaktadır?
A) |
B) İl
c) lll
D) İV
E) V
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertEqual(opts, {"A": "I", "B": "II", "C": "III", "D": "IV", "E": "V"})
        self.assertIn("gönül açmak (I);", stem)
        self.assertIn("gönül okşamak (II);", stem)
        self.assertIn("gönlüne dokunmak (III);", stem)
        self.assertIn("gönül yıkmak (IV);", stem)
        self.assertIn("gönül koymak (V)", stem)
        self.assertNotIn(" | ", stem)
        self.assertNotIn(" NI", stem)
        self.assertIn("Yukarıda numaralanmış", stem)
        self.assertLess(
            stem.index("ortak etmişiz."),
            stem.index("Yukarıda numaralanmış"),
        )

    def test_marker_attach_preserves_markdown_underline(self):
        raw = """
Parçada __gönül açmak__;
|
sonra devam.
Hangisi doğrudur?
A) I
B) II
C) III
D) IV
E) V
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertIn("__gönül açmak__ (I);", stem)
        self.assertEqual(opts["A"], "I")

    def test_option_d_wrap_stolen_from_c(self):
        """OCR: D'nin ilk satırı C'ye yapışır, D) yalnızca devam satırında."""
        raw = """
Bu parçayla ilgili aşağıdakilerden hangisi söylenemez?
A) I. cümlede söz konusu durum örneklenerek somutlaştırılmıştır.
B) II. cümlede ortaya konulan durum bir koşula dayandırılarak
detaylandırılmıştır.
C) II. cümlede savunulan fikrin gerekçesi tekrara düşülerek ele alınmıştır.
II. cümlede savunulan fikir karşılaştırma yoluna
D) gidilerek somutlaştırılmıştır.
E) III. cümlede bir çıkarım yapılmıştır.
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertIn("söylenemez", stem)
        self.assertEqual(
            opts["C"],
            "II. cümlede savunulan fikrin gerekçesi tekrara düşülerek ele alınmıştır.",
        )
        self.assertEqual(
            opts["D"],
            "II. cümlede savunulan fikir karşılaştırma yoluna gidilerek somutlaştırılmıştır.",
        )
        self.assertIn("çıkarım", opts["E"])

    def test_option_d_wrap_same_line_after_period(self):
        raw = """
Hangisi doğrudur?
A) Bir
B) İki
C) II. cümlede savunulan fikrin gerekçesi tekrara düşülerek ele alınmıştır. II. cümlede savunulan fikir karşılaştırma yoluna
D) gidilerek somutlaştırılmıştır.
E) Beş
""".strip()
        _, opts = parse_question_text(raw)
        self.assertTrue(opts["C"].endswith("alınmıştır."))
        self.assertNotIn("karşılaştırma", opts["C"])
        self.assertIn("karşılaştırma yoluna gidilerek", opts["D"])

    def test_numeric_options_not_converted_to_roman(self):
        raw = """
Sonuç kaçtır?
A) 1
B) 2
C) 3
D) 4
E) 5
""".strip()
        stem, opts = parse_question_text(raw)
        self.assertEqual(opts["A"], "1")
        self.assertEqual(opts["B"], "2")
        self.assertEqual(opts["E"], "5")
        self.assertIn("kaçtır", stem)

    @staticmethod
    def _marker_row(line: str, marks: dict[str, str]) -> str:
        """Verilen sözcüklerin altına hizalanmış madde işareti satırı üretir."""
        row = [" "] * (len(line) + 8)
        for word, marker in marks.items():
            start = line.index(word)
            col = start + max(0, (len(word) - len(marker)) // 2)
            for offset, ch in enumerate(marker):
                row[col + offset] = ch
        return "".join(row).rstrip()

    def test_marker_row_under_underlined_words(self):
        """Altı çizili sözcüklerin altındaki Romen rakamları kolon hizasıyla gömülür."""
        line1 = "Üreticilerle yüz yüze olduğunuzda tüketilen besinlerin"
        line2 = "doğal olup olmadığını, nasıl yetiştirildiğini ve tohumdan"
        raw = "\n".join(
            [
                line1,
                self._marker_row(line1, {"Üreticilerle": "I", "besinlerin": "II"}),
                line2,
                self._marker_row(line2, {"tohumdan": "III"}),
                "hasada uzanan öyküsünü öğrenmek zor değil.",
                "Bu parçada numaralanmış sözcüklerden hangisi yapım eki",
                "almamıştır?",
                "A) I",
                "B) II",
                "C) III",
                "D) IV",
                "E) V",
            ]
        )
        stem, opts = parse_question_text(raw)
        self.assertIn("Üreticilerle (I)", stem)
        self.assertIn("besinlerin (II)", stem)
        self.assertIn("tohumdan (III)", stem)
        self.assertNotIn(" | ", stem)
        self.assertEqual(opts["C"], "III")

    def test_marker_row_with_ocr_pipe_characters(self):
        line1 = "Üreticilerle yüz yüze olduğunuzda tüketilen besinlerin"
        raw = "\n".join(
            [
                line1,
                self._marker_row(line1, {"Üreticilerle": "|", "besinlerin": "II"}),
                "Hangisi yapım eki almamıştır?",
                "A) I",
                "B) II",
                "C) lii",
                "D) IV",
                "E) V",
            ]
        )
        stem, opts = parse_question_text(raw)
        self.assertIn("Üreticilerle (I)", stem)
        self.assertIn("besinlerin (II)", stem)
        self.assertEqual(opts["C"], "III")

    def test_marker_row_keeps_sentence_punctuation(self):
        line1 = "süreçlerini öğrenmek de bir o kadar güçleşiyor."
        raw = "\n".join(
            [
                line1,
                self._marker_row(line1, {"süreçlerini": "IV", "güçleşiyor": "V"}),
                "Hangisi doğrudur?",
                "A) I",
                "B) II",
                "C) III",
                "D) IV",
                "E) V",
            ]
        )
        stem, _ = parse_question_text(raw)
        self.assertIn("süreçlerini (IV)", stem)
        self.assertIn("güçleşiyor (V).", stem)

    def test_single_indented_marker_attaches_to_word_above(self):
        """Girintili tek rakam, satır başına değil üstündeki sözcüğe bağlanır."""
        line1 = "doğal olup olmadığını, nasıl yetiştirildiğini ve tohumdan"
        raw = "\n".join(
            [
                line1,
                self._marker_row(line1, {"tohumdan": "III"}),
                "Hangisi doğrudur?",
                "A) I",
                "B) II",
                "C) III",
                "D) IV",
                "E) V",
            ]
        )
        stem, _ = parse_question_text(raw)
        self.assertIn("tohumdan (III)", stem)
        self.assertNotIn("olup (III)", stem)

    def test_roman_pair_options_clean(self):
        """Noktalama sorusu: şıklar 'I ve II' gibi Romen çiftleri."""
        raw = """
Bu parçadaki numaralanmış yerlerin hangilerine noktalama
işareti getirilmelidir?
A) I ve II
B) I ve IV
C) II ve III
D) III ve V
E) IV ve V
""".strip()
        _, opts = parse_question_text(raw)
        self.assertEqual(
            opts,
            {
                "A": "I ve II",
                "B": "I ve IV",
                "C": "II ve III",
                "D": "III ve V",
                "E": "IV ve V",
            },
        )

    def test_roman_options_garbled_c_merged_into_b(self):
        """OCR: C) → cCc) ve B satırına yapışır; C boş kalmamalı."""
        raw = """
Bu parçadaki numaralanmış yerlerin hangilerine noktalama
işareti getirilmelidir?
A) I ve II
B) I ve IV cCc) II ve III
D) III ve V
E) IV ve V
""".strip()
        _, opts = parse_question_text(raw)
        self.assertEqual(opts["A"], "I ve II")
        self.assertEqual(opts["B"], "I ve IV")
        self.assertEqual(opts["C"], "II ve III")
        self.assertEqual(opts["D"], "III ve V")
        self.assertEqual(opts["E"], "IV ve V")

    def test_roman_options_garbled_c_on_own_line(self):
        raw = """
Hangisi doğrudur?
A) I ve II
B) I ve IV
cCc) II ve III
D) III ve V
E) IV ve V
""".strip()
        _, opts = parse_question_text(raw)
        self.assertEqual(opts["B"], "I ve IV")
        self.assertEqual(opts["C"], "II ve III")
        self.assertEqual(opts["D"], "III ve V")

    def test_option_emphasis_markup_is_stripped(self):
        self.assertEqual(
            strip_option_emphasis("**kalın** ve *italik*"),
            "kalın ve italik",
        )
        self.assertEqual(
            strip_option_emphasis("__altı__ $x^2$"),
            "altı $x^2$",
        )
        raw = """
Hangisi doğrudur?
A) **Türkiye**
B) *Yunanistan*
C) __Bulgaristan__
D) Düz
E) $a+b$
""".strip()
        _, opts = parse_question_text(raw)
        self.assertEqual(opts["A"], "Türkiye")
        self.assertEqual(opts["B"], "Yunanistan")
        self.assertEqual(opts["C"], "Bulgaristan")
        self.assertEqual(opts["D"], "Düz")
        self.assertEqual(opts["E"], "$a+b$")


class PanelOcrApiTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="ocr_staff", password="x", is_staff=True
        )
        self.user = User.objects.create_user(username="ocr_user", password="x")

    def _png(self) -> SimpleUploadedFile:
        img = Image.new("RGB", (400, 120), "white")
        ImageDraw.Draw(img).text((20, 40), "A) 1  B) 2", fill="black")
        buf = BytesIO()
        img.save(buf, format="PNG")
        return SimpleUploadedFile("q.png", buf.getvalue(), content_type="image/png")

    def test_staff_can_ocr(self):
        self.client.force_login(self.staff)
        res = self.client.post("/panel/api/ocr-question/", {"image": self._png()})
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("stem", data)
        self.assertIn("options", data)
        self.assertIn("raw_text", data)
        self.assertIn("duplicate", data)
        for key in "ABCDE":
            self.assertIn(key, data["options"])

    def test_non_staff_redirected(self):
        self.client.force_login(self.user)
        res = self.client.post("/panel/api/ocr-question/", {"image": self._png()})
        self.assertIn(res.status_code, (302, 403))

    def test_missing_image_400(self):
        self.client.force_login(self.staff)
        res = self.client.post("/panel/api/ocr-question/", {})
        self.assertEqual(res.status_code, 400)


class PanelQuestionBulkDeleteTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="bulk_staff", password="x", is_staff=True
        )
        from content.models import Question, Subject, Topic

        self.subject = Subject.objects.create(slug="bulk_d", name="Bulk Ders")
        self.topic = Topic.objects.create(
            subject=self.subject, slug="bulk_k", name="Bulk Konu"
        )
        self.other = Topic.objects.create(
            subject=self.subject, slug="bulk_k2", name="Diğer"
        )
        self.q1 = Question.objects.create(
            topic=self.topic,
            public_id="q_bulk_1",
            stem="S1",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
        )
        self.q2 = Question.objects.create(
            topic=self.topic,
            public_id="q_bulk_2",
            stem="S2",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
        )
        self.q3 = Question.objects.create(
            topic=self.topic,
            public_id="q_bulk_3",
            stem="S3",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
        )
        self.foreign = Question.objects.create(
            topic=self.other,
            public_id="q_bulk_x",
            stem="SX",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
        )

    def test_bulk_delete_selected(self):
        self.client.force_login(self.staff)
        url = f"/panel/konu/{self.topic.id}/soru/toplu-sil/"
        res = self.client.post(url, {"ids": [self.q1.id, self.q2.id]})
        self.assertEqual(res.status_code, 302)
        self.assertFalse(Question.objects.filter(pk=self.q1.id).exists())
        self.assertFalse(Question.objects.filter(pk=self.q2.id).exists())
        self.assertTrue(Question.objects.filter(pk=self.q3.id).exists())
        self.assertTrue(Question.objects.filter(pk=self.foreign.id).exists())

    def test_bulk_delete_ignores_other_topic_ids(self):
        self.client.force_login(self.staff)
        url = f"/panel/konu/{self.topic.id}/soru/toplu-sil/"
        res = self.client.post(url, {"ids": [self.q1.id, self.foreign.id]})
        self.assertEqual(res.status_code, 302)
        self.assertFalse(Question.objects.filter(pk=self.q1.id).exists())
        self.assertTrue(Question.objects.filter(pk=self.foreign.id).exists())


class QuestionFingerprintTests(TestCase):
    def setUp(self):
        from content.models import Subject, Topic

        self.subject = Subject.objects.create(slug="fp_d", name="FP Ders")
        self.topic = Topic.objects.create(
            subject=self.subject, slug="fp_k", name="FP Konu"
        )

    def test_same_content_detected(self):
        from content.question_fingerprint import (
            content_fingerprint,
            find_duplicate_question,
        )

        q = Question.objects.create(
            topic=self.topic,
            public_id="q_fp_a",
            stem="Hangisi doğrudur? Örnek uzun soru metni.",
            option_a="Bir",
            option_b="İki",
            option_c="Üç",
            option_d="Dört",
            option_e="Beş",
            source_image_hash="imghash1",
        )
        c = content_fingerprint(
            q.stem, q.option_a, q.option_b, q.option_c, q.option_d, q.option_e
        )
        dup, match = find_duplicate_question(
            content_hash=c, image_hash="imghash1"
        )
        self.assertEqual(dup.id, q.id)
        self.assertEqual(match, "image")

        dup2, match2 = find_duplicate_question(
            content_hash=c, image_hash="farkli"
        )
        self.assertEqual(dup2.id, q.id)
        self.assertEqual(match2, "content")

    def test_normalized_punctuation_match(self):
        from content.question_fingerprint import content_fingerprint

        a = content_fingerprint(
            "Hangisi doğrudur?",
            "A seçenek",
            "B seçenek",
            "C seçenek",
            "D seçenek",
            "E seçenek",
        )
        c = content_fingerprint(
            "Hangisi doğrudur?",
            "A seçenek.",
            "B seçenek",
            "C seçenek",
            "D seçenek",
            "E seçenek",
        )
        self.assertEqual(a, c)

    def test_quick_upload_blocks_duplicate_image(self):
        User = get_user_model()
        staff = User.objects.create_user(
            username="fp_staff", password="x", is_staff=True
        )
        from content.question_fingerprint import image_fingerprint

        img = Image.new("RGB", (320, 80), "white")
        ImageDraw.Draw(img).text((10, 30), "uniq-fp-img", fill="black")
        buf = BytesIO()
        img.save(buf, format="PNG")
        raw = buf.getvalue()
        img_hash = image_fingerprint(raw)
        Question.objects.create(
            topic=self.topic,
            public_id="q_fp_exist",
            stem="Mevcut soru metni burada yeterince uzun.",
            option_a="a1",
            option_b="b1",
            option_c="c1",
            option_d="d1",
            option_e="e1",
            source_image_hash=img_hash,
        )

        self.client.force_login(staff)
        upload = SimpleUploadedFile("q.png", raw, content_type="image/png")
        before = Question.objects.count()
        res = self.client.post(
            "/panel/soru/hizli/",
            {
                "subject_id": self.subject.id,
                "topic_id": self.topic.id,
                "test_assignment": "auto",
                "image": upload,
            },
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(Question.objects.count(), before)
        self.assertContains(res, "daha önce")

    def test_quick_upload_does_not_save_until_edit_form(self):
        User = get_user_model()
        staff = User.objects.create_user(
            username="fp_staff2", password="x", is_staff=True
        )
        img = Image.new("RGB", (320, 80), "white")
        ImageDraw.Draw(img).text((10, 30), "new-quick-upload", fill="black")
        buf = BytesIO()
        img.save(buf, format="PNG")
        raw = buf.getvalue()

        self.client.force_login(staff)
        upload = SimpleUploadedFile("q.png", raw, content_type="image/png")
        before = Question.objects.count()
        res = self.client.post(
            "/panel/soru/hizli/",
            {
                "subject_id": self.subject.id,
                "topic_id": self.topic.id,
                "test_assignment": "auto",
                "image": upload,
            },
        )
        self.assertEqual(res.status_code, 302)
        self.assertEqual(Question.objects.count(), before)
        edit = self.client.get(res.url)
        self.assertEqual(edit.status_code, 200)
        self.assertContains(edit, "Görselden soru")
        self.assertContains(edit, "Henüz kaydedilmedi")


class PanelTopicManageTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="topic_staff", password="x", is_staff=True
        )
        from content.models import Subject, Topic

        self.subject = Subject.objects.create(slug="mat", name="Matematik")
        self.t1 = Topic.objects.create(
            subject=self.subject, slug="mat_a", name="Konu A", sort_order=1
        )
        self.t2 = Topic.objects.create(
            subject=self.subject, slug="mat_b", name="Konu B", sort_order=2
        )

    def test_create_topic(self):
        self.client.force_login(self.staff)
        res = self.client.post(
            f"/panel/ders/{self.subject.id}/konu/yeni/",
            {
                "name": "Üslü Sayılar",
                "questions_per_test": "10",
                "is_active": "on",
            },
        )
        self.assertEqual(res.status_code, 302)
        from content.models import Topic

        topic = Topic.objects.get(subject=self.subject, name="Üslü Sayılar")
        self.assertTrue(topic.slug.startswith("mat_"))
        self.assertGreater(topic.sort_order, self.t2.sort_order)

    def test_reorder_topics_from_drag_order(self):
        self.client.force_login(self.staff)
        res = self.client.post(
            f"/panel/ders/{self.subject.id}/konular/sirala/",
            {"topic_ids": [str(self.t2.id), str(self.t1.id)]},
        )
        self.assertEqual(res.status_code, 204)
        self.t1.refresh_from_db()
        self.t2.refresh_from_db()
        self.assertEqual(self.t1.sort_order, 2)
        self.assertEqual(self.t2.sort_order, 1)

    def test_delete_topic_removes_questions(self):
        from content.models import Question, Topic

        Question.objects.create(
            topic=self.t1,
            public_id="q_del_topic_1",
            stem="Silinecek konu sorusu",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )
        self.client.force_login(self.staff)
        res = self.client.post(
            f"/panel/ders/{self.subject.id}/konu/{self.t1.id}/sil/"
        )
        self.assertEqual(res.status_code, 302)
        self.assertEqual(res.url, f"/panel/ders/{self.subject.id}/")
        self.assertFalse(Topic.objects.filter(pk=self.t1.id).exists())
        self.assertFalse(Question.objects.filter(public_id="q_del_topic_1").exists())
        self.assertTrue(Topic.objects.filter(pk=self.t2.id).exists())

    def test_delete_topic_requires_staff(self):
        User = get_user_model()
        user = User.objects.create_user(username="topic_user", password="x")
        self.client.force_login(user)
        res = self.client.post(
            f"/panel/ders/{self.subject.id}/konu/{self.t1.id}/sil/"
        )
        self.assertIn(res.status_code, (302, 403))
        from content.models import Topic

        self.assertTrue(Topic.objects.filter(pk=self.t1.id).exists())


class QuestionCopyTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="copy_staff", password="x", is_staff=True
        )
        from content.models import Subject, Topic

        self.subject = Subject.objects.create(slug="tr_copy", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=self.subject, slug="tr_copy_k", name="Anlam"
        )
        self.source = Question.objects.create(
            topic=self.topic,
            public_id="q_copy_src",
            stem="Aynı metinden türetilecek örnek soru.",
            option_a="I ve II",
            option_b="I ve IV",
            option_c="II ve III",
            option_d="III ve V",
            option_e="IV ve V",
            correct_option="B",
            solution="Açıklama metni",
            is_published=True,
            osym_sordu=True,
            attempt_count=12,
            correct_count=5,
            option_a_count=2,
        )

    def test_copy_creates_new_public_id_and_resets_stats(self):
        self.client.force_login(self.staff)
        before = Question.objects.count()
        res = self.client.post(f"/panel/soru/{self.source.id}/kopyala/")
        self.assertEqual(res.status_code, 302)
        self.assertEqual(Question.objects.count(), before + 1)

        copy = Question.objects.exclude(pk=self.source.id).get(topic=self.topic)
        self.assertNotEqual(copy.public_id, self.source.public_id)
        self.assertNotEqual(copy.pk, self.source.pk)
        self.assertEqual(copy.stem, self.source.stem)
        self.assertEqual(copy.option_b, "I ve IV")
        self.assertEqual(copy.correct_option, "B")
        self.assertEqual(copy.solution, "Açıklama metni")
        self.assertTrue(copy.is_published)
        self.assertTrue(copy.osym_sordu)
        self.assertEqual(copy.attempt_count, 0)
        self.assertEqual(copy.correct_count, 0)
        self.assertEqual(copy.option_a_count, 0)
        self.assertEqual(res.url, f"/panel/konu/{self.topic.id}/soru/{copy.id}/")

    def test_copy_requires_staff(self):
        User = get_user_model()
        user = User.objects.create_user(username="copy_user", password="x")
        self.client.force_login(user)
        res = self.client.post(f"/panel/soru/{self.source.id}/kopyala/")
        self.assertIn(res.status_code, (302, 403))
        self.assertEqual(Question.objects.filter(topic=self.topic).count(), 1)


class QuestionOsymSorduTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="osym_staff", password="x", is_staff=True
        )
        from content.models import Subject, Topic

        self.subject = Subject.objects.create(slug="tr_osym", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=self.subject, slug="tr_anlam", name="Anlam"
        )

    def _question_payload(self, **extra):
        data = {
            "subject_id": self.subject.id,
            "topic_id": self.topic.id,
            "subtopic": "",
            "stem": "ÖSYM kaynaklı örnek soru metni yeterince uzun.",
            "option_a": "A şıkkı",
            "option_b": "B şıkkı",
            "option_c": "C şıkkı",
            "option_d": "D şıkkı",
            "option_e": "E şıkkı",
            "correct_option": "A",
            "solution": "",
            "test_assignment": "auto",
            "is_published": "on",
        }
        data.update(extra)
        return data

    def test_panel_save_osym_sordu_flag(self):
        self.client.force_login(self.staff)
        res = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            self._question_payload(osym_sordu="on"),
        )
        self.assertEqual(res.status_code, 302)
        question = Question.objects.get(topic=self.topic)
        self.assertTrue(question.osym_sordu)

    def test_api_exposes_osym_sordu(self):
        from content.serializers import QuestionSerializer

        question = Question.objects.create(
            topic=self.topic,
            public_id="q_osym_1",
            stem="Metin",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            osym_sordu=True,
        )
        data = QuestionSerializer(question).data
        self.assertTrue(data["osymSordu"])
