from datetime import timedelta

from django.test import Client, TestCase
from django.utils import timezone

from content.auth import new_api_token
from content.models import AppUser, Question, Subject, TgExam, Topic


class TgExamQuestionsApiTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="tarih", name="Tarih")
        topic = Topic.objects.create(subject=subject, slug="tarih_temel", name="Temel")
        self.questions = []
        for i in range(3):
            q = Question.objects.create(
                topic=topic,
                public_id=f"tg_q_{i}",
                stem=f"Soru {i}",
                option_a="A",
                option_b="B",
                option_c="C",
                option_d="D",
                option_e="E",
                correct_option="A",
                is_published=True,
            )
            self.questions.append(q)
        now = timezone.now()
        self.exam = TgExam.objects.create(
            title="TG Questions API",
            kpss_type="lisans",
            start_at=now - timedelta(hours=1),
            end_at=now + timedelta(hours=2),
            duration_minutes=130,
            question_ids=[q.public_id for q in self.questions],
            is_published=True,
        )
        self.user = AppUser.objects.create(
            google_sub="tg-questions-user",
            email="tgq@example.com",
            display_name="TG User",
            api_token=new_api_token(),
        )
        self.client = Client()

    def test_questions_endpoint_returns_ordered_payload(self):
        response = self.client.get(
            f"/api/v1/tg-exams/{self.exam.pk}/questions/",
            HTTP_AUTHORIZATION=f"Bearer {self.user.api_token}",
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(len(body["questions"]), 3)
        self.assertEqual(
            [row["id"] for row in body["questions"]],
            [q.public_id for q in self.questions],
        )
