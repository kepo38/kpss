from django.test import TestCase
from django.urls import reverse

from content.models import (
    AppUser,
    Question,
    QuestionErrorReport,
    Subject,
    Topic,
    TopicTest,
    TopicTestCompletion,
)


class QuestionErrorReportApiTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="ilk-turk-devletleri",
            name="İlk Türk Devletleri",
        )
        self.question = Question.objects.create(
            topic=self.topic,
            public_id="q_err_1",
            stem="Hangisi doğrudur?",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=True,
        )
        self.user = AppUser.objects.create(
            google_sub="err-sub-1",
            email="err@example.com",
            display_name="Öğrenci",
            api_token="err-token-1",
        )

    def url(self) -> str:
        return reverse(
            "question-error-report",
            kwargs={"public_id": self.question.public_id},
        )

    def auth(self) -> dict[str, str]:
        return {"HTTP_AUTHORIZATION": f"Bearer {self.user.api_token}"}

    def _complete_tests(self, count: int) -> None:
        for index in range(count):
            test = TopicTest.objects.create(
                public_id=f"tt_err_{index}",
                topic=self.topic,
                title=f"Test {index}",
                is_published=True,
            )
            TopicTestCompletion.objects.create(user=self.user, topic_test=test)

    def test_get_premium_requires_three_tests(self):
        self.user.grant_free_premium(note="test")
        self._complete_tests(3)
        response = self.client.get(self.url(), **self.auth())
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["minTestsRequired"], 3)
        self.assertTrue(body["testsRequirementMet"])
        self.assertTrue(body["canReport"])

    def test_post_premium_blocked_under_three_tests(self):
        self.user.grant_free_premium(note="test")
        self._complete_tests(2)
        response = self.client.post(
            self.url(),
            data={"category": "typo", "note": ""},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["minTestsRequired"], 3)
        self.assertEqual(QuestionErrorReport.objects.count(), 0)

    def test_post_premium_allowed_after_three_tests(self):
        self.user.grant_free_premium(note="test")
        self._complete_tests(3)
        response = self.client.post(
            self.url(),
            data={"category": "typo", "note": "yazım"},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(QuestionErrorReport.objects.count(), 1)

    def test_post_free_still_requires_five_tests(self):
        self._complete_tests(3)
        response = self.client.post(
            self.url(),
            data={"category": "typo", "note": ""},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["minTestsRequired"], 5)
        self.assertEqual(QuestionErrorReport.objects.count(), 0)
