from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone

from content.models import (
    AppUser,
    Question,
    Subject,
    TgExam,
    TgExamAttempt,
    Topic,
)
from content.tg_exam.ranking import auto_submit_open_attempts, publish_exam_results
from content.tg_exam.generator import TgExamGeneratorService


class TgExamAutoSubmitTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="matematik", name="Matematik")
        self.topic = Topic.objects.create(
            subject=subject, slug="mat_temel", name="Temel"
        )
        self.questions = []
        for i in range(3):
            q = Question.objects.create(
                topic=self.topic,
                public_id=f"q_auto_{i}",
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
        self.exam = TgExam.objects.create(
            title="Auto Submit Exam",
            kpss_type="lisans",
            start_at=timezone.now() - timedelta(hours=3),
            end_at=timezone.now() - timedelta(minutes=1),
            duration_minutes=130,
            question_ids=[q.public_id for q in self.questions],
            is_published=True,
            is_results_published=False,
        )
        self.user = AppUser.objects.create(
            google_sub=f"auto-sub-{timezone.now().timestamp()}",
            email="auto@example.com",
            display_name="Auto",
        )

    def test_auto_submit_grades_open_attempts(self):
        attempt = TgExamAttempt.objects.create(
            user=self.user,
            exam=self.exam,
            answers={self.questions[0].public_id: "A"},
            elapsed_seconds=90,
            is_submitted=False,
        )
        count = auto_submit_open_attempts(self.exam)
        self.assertEqual(count, 1)
        attempt.refresh_from_db()
        self.assertTrue(attempt.is_submitted)
        self.assertEqual(attempt.correct, 1)
        self.assertEqual(attempt.wrong, 0)
        self.assertEqual(attempt.blank, 2)
        self.assertEqual(attempt.duration_seconds, 90)
        self.assertIsNotNone(attempt.submitted_at)

    def test_publish_results_auto_submits_then_ranks(self):
        TgExamAttempt.objects.create(
            user=self.user,
            exam=self.exam,
            answers={self.questions[0].public_id: "A"},
            elapsed_seconds=40,
            is_submitted=False,
        )
        ok = publish_exam_results(self.exam, send_push=False)
        self.assertTrue(ok)
        self.exam.refresh_from_db()
        self.assertTrue(self.exam.is_results_published)
        attempt = TgExamAttempt.objects.get(user=self.user, exam=self.exam)
        self.assertTrue(attempt.is_submitted)
        self.assertEqual(attempt.ranking, 1)


class TgExamPublishGateTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="staff_tg", password="x", is_staff=True
        )
        self.client = Client()
        self.client.force_login(self.staff)
        subject = Subject.objects.create(slug="tarih", name="Tarih")
        topic = Topic.objects.create(subject=subject, slug="t1", name="T1")
        self.exam = TgExam.objects.create(
            title="Short",
            kpss_type="lisans",
            start_at=timezone.now() + timedelta(hours=3),
            end_at=timezone.now() + timedelta(hours=6),
            duration_minutes=130,
            question_ids=["q_only_one"],
            is_published=False,
        )
        Question.objects.create(
            topic=topic,
            public_id="q_only_one",
            stem="S",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            correct_option="A",
            is_published=True,
        )

    def test_publish_blocked_when_question_count_mismatch(self):
        from unittest.mock import patch

        with patch.object(TgExamGeneratorService, "slot_count", return_value=120):
            response = self.client.post(
                f"/panel/tg-deneme/{self.exam.pk}/yayinla/"
            )
        self.assertEqual(response.status_code, 302)
        self.exam.refresh_from_db()
        self.assertFalse(self.exam.is_published)


class TgExamCooldownRepublishTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="staff_cd", password="x", is_staff=True
        )
        self.client = Client()
        self.client.force_login(self.staff)
        self.exam = TgExam.objects.create(
            title="Cooldownoldown",
            kpss_type="lisans",
            start_at=timezone.now() + timedelta(hours=3),
            end_at=timezone.now() + timedelta(hours=6),
            duration_minutes=130,
            question_ids=["q1", "q2"],
            is_published=True,
            tg_usage_recorded=True,
        )

    def test_unpublish_resets_tg_usage_recorded(self):
        response = self.client.post(
            f"/panel/tg-deneme/{self.exam.pk}/yayindan-kaldir/"
        )
        self.assertEqual(response.status_code, 302)
        self.exam.refresh_from_db()
        self.assertFalse(self.exam.is_published)
        self.assertFalse(self.exam.tg_usage_recorded)
