from django.test import TestCase
from django.urls import reverse

from content.models import Question, Subject, Topic
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
) -> Question:
    return Question.objects.create(
        topic=topic,
        public_id=public_id,
        stem=f"{public_id}?",
        option_a="A",
        option_b="B",
        option_c="C",
        option_d="D",
        option_e="E",
        correct_option="A",
        is_published=published,
        map_template=map_template,
    )


class SpecialTestsBuilderTests(TestCase):
    def setUp(self):
        self.geo = Subject.objects.create(slug="cografya", name="Coğrafya")
        self.turkce = Subject.objects.create(slug="turkce", name="Türkçe")
        self.geo_topic = Topic.objects.create(
            subject=self.geo,
            slug="turkiye_cografyasi",
            name="Türkiye Coğrafyası",
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
        category = payload["categories"][0]
        self.assertEqual(category["id"], MAP_GEOGRAPHY_ID)
        self.assertEqual(category["questionCount"], 40)
        self.assertEqual(len(category["tests"]), 2)
        self.assertEqual(category["tests"][0]["id"], "special_map_cografya_1")
        self.assertEqual(category["tests"][0]["questionCount"], 20)
        self.assertEqual(len(category["tests"][0]["questionIds"]), 20)

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
        self.assertEqual(len(body["categories"]), 1)
        self.assertEqual(body["categories"][0]["questionCount"], 1)
        self.assertEqual(body["categories"][0]["tests"][0]["questionIds"], ["q_map_api"])
