from django.test import TestCase

from django.urls import reverse



from content.models import Question, Subject, Topic

from content.special_question_tags import apply_auto_tags, suggest_tags

from content.special_tests import (

    MAP_GEOGRAPHY_ID,

    QUESTIONS_PER_TEST,

    build_special_tests_payload,

    chunk_questions,

    map_geography_questions,

)





def _make_question(

    topic: Topic,

    *,

    public_id: str,

    map_template: str = "",

    published: bool = True,

    stem: str | None = None,

    tag_kronoloji: bool = False,

    tag_padisah_antlasma: bool = False,

    tag_celdirici: bool = False,

) -> Question:

    return Question.objects.create(

        topic=topic,

        public_id=public_id,

        stem=stem or f"{public_id}?",

        option_a="A",

        option_b="B",

        option_c="C",

        option_d="D",

        option_e="E",

        correct_option="A",

        is_published=published,

        map_template=map_template,

        tag_kronoloji=tag_kronoloji,

        tag_padisah_antlasma=tag_padisah_antlasma,

        tag_celdirici=tag_celdirici,

    )





class SpecialQuestionTagsTests(TestCase):

    def test_suggest_kronoloji_and_padisah(self):

        self.assertIn(

            "tag_kronoloji",

            suggest_tags("Aşağıdakilerden hangisi daha önce gerçekleşmiştir?"),

        )

        self.assertIn(

            "tag_padisah_antlasma",

            suggest_tags("Kanuni Sultan Süleyman döneminde imzalanan antlaşma hangisidir?"),

        )

        self.assertEqual(suggest_tags("Türkiye'nin başkenti neresidir?"), set())



    def test_apply_auto_tags_only_raises(self):

        geo = Subject.objects.create(slug="cografya", name="Coğrafya")

        topic = Topic.objects.create(

            subject=geo, slug="t", name="T"

        )

        q = Question(

            topic=topic,

            public_id="q_auto",

            stem="Olayların kronolojik sırası hangisidir?",

            option_a="A",

            option_b="B",

            option_c="C",

            option_d="D",

            option_e="E",

            correct_option="A",

            tag_kronoloji=False,

        )

        raised = apply_auto_tags(q, only_raise=True)

        self.assertIn("tag_kronoloji", raised)

        self.assertTrue(q.tag_kronoloji)

        q.tag_kronoloji = True

        raised2 = apply_auto_tags(q, only_raise=True)

        self.assertEqual(raised2, set())





class SpecialTestsBuilderTests(TestCase):

    def setUp(self):

        self.geo = Subject.objects.create(slug="cografya", name="Coğrafya")

        self.tarih = Subject.objects.create(slug="tarih", name="Tarih")

        self.turkce = Subject.objects.create(slug="turkce", name="Türkçe")

        self.geo_topic = Topic.objects.create(

            subject=self.geo,

            slug="turkiye_cografyasi",

            name="Türkiye Coğrafyası",

        )

        self.tarih_topic = Topic.objects.create(

            subject=self.tarih,

            slug="osmanli",

            name="Osmanlı",

        )

        self.tr_topic = Topic.objects.create(

            subject=self.turkce,

            slug="turkce_anlam",

            name="Anlam",

        )



    def test_forty_map_questions_make_two_tests_of_twenty(self):

        for i in range(40):

            _make_question(

                self.geo_topic,

                public_id=f"q_map_{i:02d}",

                map_template="turkiye_goller",

            )

        for i in range(3):

            _make_question(self.geo_topic, public_id=f"q_plain_{i}")

        _make_question(

            self.geo_topic,

            public_id="q_map_unpublished",

            map_template="turkiye_goller",

            published=False,

        )

        _make_question(

            self.tr_topic,

            public_id="q_map_turkce",

            map_template="turkiye_goller",

        )



        selected = map_geography_questions()

        self.assertEqual(len(selected), 40)

        chunks = chunk_questions(selected)

        self.assertEqual(len(chunks), 2)

        self.assertEqual(len(chunks[0]), QUESTIONS_PER_TEST)

        self.assertEqual(len(chunks[1]), QUESTIONS_PER_TEST)



        payload = build_special_tests_payload()

        self.assertEqual(len(payload["categories"]), 4)

        category = payload["categories"][0]

        self.assertEqual(category["id"], MAP_GEOGRAPHY_ID)

        self.assertEqual(category["questionCount"], 40)

        self.assertEqual(len(category["tests"]), 2)

        self.assertEqual(category["tests"][0]["id"], "special_map_cografya_1")

        self.assertEqual(category["tests"][0]["questionCount"], 20)

        self.assertEqual(len(category["tests"][0]["questionIds"]), 20)

        self.assertEqual(payload["categories"][1]["id"], "tarih-kronoloji")

        self.assertEqual(payload["categories"][2]["id"], "padisahlar-antlasmalar")

        self.assertEqual(payload["categories"][3]["id"], "celdiricisi-guclu")



    def test_flagged_questions_fill_special_categories(self):

        for i in range(20):

            _make_question(

                self.tarih_topic,

                public_id=f"q_kron_{i:02d}",

                tag_kronoloji=True,

            )

        _make_question(

            self.tarih_topic,

            public_id="q_pad_01",

            tag_padisah_antlasma=True,

        )

        _make_question(

            self.tr_topic,

            public_id="q_cel_01",

            tag_celdirici=True,

        )

        # Bayraksız tarih sorusu havuza girmez

        _make_question(self.tarih_topic, public_id="q_plain_tarih")



        payload = build_special_tests_payload()

        by_id = {c["id"]: c for c in payload["categories"]}

        self.assertEqual(by_id["tarih-kronoloji"]["questionCount"], 20)

        self.assertEqual(len(by_id["tarih-kronoloji"]["tests"]), 1)

        self.assertEqual(

            by_id["tarih-kronoloji"]["tests"][0]["questionCount"], 20

        )

        self.assertEqual(by_id["padisahlar-antlasmalar"]["questionCount"], 1)

        self.assertEqual(by_id["celdiricisi-guclu"]["questionCount"], 1)

        self.assertEqual(

            by_id["celdiricisi-guclu"]["tests"][0]["questionIds"], ["q_cel_01"]

        )



    def test_save_auto_tags_from_stem(self):

        q = _make_question(

            self.tarih_topic,

            public_id="q_auto_save",

            stem="Hangisi daha önce gerçekleşmiştir?",

        )

        q.refresh_from_db()

        self.assertTrue(q.tag_kronoloji)

        payload = build_special_tests_payload()

        kron = next(c for c in payload["categories"] if c["id"] == "tarih-kronoloji")

        self.assertIn("q_auto_save", kron["tests"][0]["questionIds"])



    def test_remainder_becomes_last_shorter_test(self):

        for i in range(25):

            _make_question(

                self.geo_topic,

                public_id=f"q_map_r_{i:02d}",

                map_template="turkiye_goller",

            )

        tests = build_special_tests_payload()["categories"][0]["tests"]

        self.assertEqual(len(tests), 2)

        self.assertEqual(tests[0]["questionCount"], 20)

        self.assertEqual(tests[1]["questionCount"], 5)



    def test_api_returns_categories(self):

        _make_question(

            self.geo_topic,

            public_id="q_map_api",

            map_template="turkiye_goller",

        )

        response = self.client.get(reverse("special-tests"))

        self.assertEqual(response.status_code, 200)

        body = response.json()

        self.assertEqual(len(body["categories"]), 4)

        self.assertEqual(body["categories"][0]["id"], MAP_GEOGRAPHY_ID)

        self.assertEqual(body["categories"][0]["questionCount"], 1)

        self.assertEqual(body["categories"][0]["tests"][0]["questionIds"], ["q_map_api"])

        self.assertEqual(body["categories"][1]["title"], "TARİH KRONOLOJİ")

        self.assertEqual(body["categories"][2]["title"], "PADİŞAHLAR VE ANTLAŞMALAR")

        self.assertEqual(body["categories"][3]["title"], "ÇELDİRİCİSİ GÜÇLÜ SORULAR")


