from django.test import TestCase
from django.urls import reverse

from content.models import Question, Subject, Topic, TopicTest


class CloudContentApiTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="turkce", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=subject,
            slug="turkce_anlam",
            name="Anlam",
        )
        self.questions = []
        for i in range(3):
            self.questions.append(
                Question.objects.create(
                    topic=self.topic,
                    public_id=f"q_cloud_{i}",
                    stem=f"Soru {i}?",
                    option_a="A",
                    option_b="B",
                    option_c="C",
                    option_d="D",
                    option_e="E",
                    correct_option="A",
                    is_published=True,
                )
            )
        self.test = TopicTest.objects.create(
            topic=self.topic,
            public_id="test_cloud_1",
            title="Bulut Test",
            is_published=True,
        )
        self.test.questions.set(self.questions)

    def test_catalog_excludes_question_bodies(self):
        response = self.client.get(reverse("content-catalog"))
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("tests", body)
        self.assertIn("subjects", body)
        self.assertNotIn("questions", body)

    def test_test_questions_endpoint_returns_only_that_test(self):
        url = reverse("test-questions", kwargs={"test_id": self.test.public_id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["testId"], self.test.public_id)
        self.assertEqual(len(body["questions"]), 3)

    def test_questions_filter_by_ids(self):
        url = reverse("questions")
        response = self.client.get(url, {"ids": "q_cloud_0,q_cloud_2"})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(len(body), 2)
        ids = {item["id"] for item in body}
        self.assertEqual(ids, {"q_cloud_0", "q_cloud_2"})
