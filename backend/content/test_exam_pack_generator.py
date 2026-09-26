from django.test import TestCase

from .exam_pack_generator import ExamPackGeneratorError, generate_pack_exams
from .exam_pack_personalize import (
    max_previously_answered,
    personalize_exam_questions,
)
from .models import (
    AppUser,
    ExamDistributionTemplate,
    ExamPack,
    ExamPackExam,
    ExamPackExamQuestion,
    ExamType,
    Question,
    QuestionAttempt,
    Subject,
    Topic,
)


def _quality_question(*, topic: Topic, public_id: str, stem: str) -> Question:
    return Question.objects.create(
        public_id=public_id,
        topic=topic,
        stem=stem,
        option_a="A",
        option_b="B",
        option_c="C",
        option_d="D",
        option_e="E",
        correct_option="A",
        is_published=True,
        difficulty=Question.DIFFICULTY_MEDIUM,
        attempt_count=Question.DIFFICULTY_MIN_ATTEMPTS,
    )


class ExamPackGeneratorTests(TestCase):
    def setUp(self):
        self.exam_type = ExamType.objects.create(
            slug="kpss_test_gen",
            name="KPSS Test",
            exam_date="2026-07-12",
        )
        self.subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topic_a = Topic.objects.create(
            subject=self.subject,
            slug="ilk_cag",
            name="İlk Çağ",
        )
        self.topic_b = Topic.objects.create(
            subject=self.subject,
            slug="osmanli",
            name="Osmanlı",
        )
        for i, topic in enumerate([self.topic_a, self.topic_b], start=1):
            for j in range(1, 16):
                _quality_question(
                    topic=topic,
                    public_id=f"q_gen_{topic.slug}_{j}",
                    stem=f"Soru {i}-{j}",
                )

        ExamDistributionTemplate.objects.create(
            exam_type=self.exam_type,
            subject=self.subject,
            topic=self.topic_a,
            question_count=5,
        )
        ExamDistributionTemplate.objects.create(
            exam_type=self.exam_type,
            subject=self.subject,
            topic=self.topic_b,
            question_count=5,
        )

        self.pack = ExamPack.objects.create(
            public_id="ep_test_tarih",
            exam_type=self.exam_type,
            pack_kind=ExamPack.PACK_KIND_BRANCH,
            subject=self.subject,
            title="Tarih 10 Deneme",
            exam_count=2,
            time_limit_minutes=45,
            is_published=True,
        )

    def test_generate_branch_pack_creates_exams_with_questions(self):
        created = generate_pack_exams(self.pack, replace=True, seed=42)
        self.assertEqual(len(created), 2)
        self.assertEqual(ExamPackExam.objects.filter(pack=self.pack).count(), 2)
        first = ExamPackExam.objects.get(pack=self.pack, index=1)
        self.assertEqual(first.question_count, 10)

    def test_generate_fails_when_pool_insufficient(self):
        Question.objects.all().delete()
        _quality_question(
            topic=self.topic_a,
            public_id="q_only_one",
            stem="Tek soru",
        )
        with self.assertRaises(ExamPackGeneratorError):
            generate_pack_exams(self.pack, replace=True)

    def test_skips_unpublished_and_unproven_questions(self):
        Question.objects.all().delete()
        Question.objects.create(
            public_id="q_unproven",
            topic=self.topic_a,
            stem="Az cevaplı",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            correct_option="A",
            is_published=True,
            difficulty=Question.DIFFICULTY_MEDIUM,
            attempt_count=50,
        )
        Question.objects.create(
            public_id="q_easy",
            topic=self.topic_a,
            stem="Kolay",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            correct_option="A",
            is_published=True,
            difficulty=Question.DIFFICULTY_EASY,
            attempt_count=Question.DIFFICULTY_MIN_ATTEMPTS,
        )
        with self.assertRaises(ExamPackGeneratorError):
            generate_pack_exams(self.pack, replace=True)


class ExamPackPersonalizeTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topic = Topic.objects.create(
            subject=subject, slug="ilk_cag", name="İlk Çağ"
        )
        self.assigned = [
            _quality_question(
                topic=self.topic,
                public_id=f"q_asg_{i}",
                stem=f"Atanan {i}",
            )
            for i in range(10)
        ]
        self.replacements = [
            _quality_question(
                topic=self.topic,
                public_id=f"q_rep_{i}",
                stem=f"Yedek {i}",
            )
            for i in range(8)
        ]
        self.user = AppUser.objects.create(
            google_sub="pack-user-1",
            email="pack@example.test",
            api_token="pack-token-1",
        )

    def test_max_previously_answered_is_floor_20_percent(self):
        self.assertEqual(max_previously_answered(10), 2)
        self.assertEqual(max_previously_answered(27), 5)

    def test_replaces_excess_previously_answered_questions(self):
        for question in self.assigned[:5]:
            QuestionAttempt.objects.create(
                question=question,
                user=self.user,
                outcome=QuestionAttempt.OUTCOME_WRONG,
                selected_option="B",
            )
        result = personalize_exam_questions(
            self.assigned, self.user, seed=7
        )
        self.assertEqual(len(result), 10)
        seen = QuestionAttempt.objects.filter(
            user=self.user,
            question_id__in=[q.id for q in result],
        ).count()
        self.assertLessEqual(seen, 2)
        assigned_ids = {q.id for q in self.assigned}
        self.assertTrue(any(q.id not in assigned_ids for q in result))


class ExamPackQuestionsApiTests(TestCase):
    def setUp(self):
        exam_type = ExamType.objects.create(
            slug="kpss_api_pack",
            name="KPSS API",
            exam_date="2026-07-12",
        )
        subject = Subject.objects.create(slug="tarih", name="Tarih")
        topic = Topic.objects.create(
            subject=subject, slug="ilk_cag", name="İlk Çağ"
        )
        self.pack = ExamPack.objects.create(
            public_id="ep_api_tarih",
            exam_type=exam_type,
            pack_kind=ExamPack.PACK_KIND_BRANCH,
            subject=subject,
            title="Tarih API",
            exam_count=1,
            is_published=True,
        )
        self.exam = ExamPackExam.objects.create(
            pack=self.pack, index=1, title="Tarih Deneme 1"
        )
        question = _quality_question(
            topic=topic, public_id="q_api_1", stem="API soru"
        )
        ExamPackExamQuestion.objects.create(
            exam=self.exam, question=question, sort_order=0
        )
        self.google_user = AppUser.objects.create(
            google_sub="pack-api-google",
            email="google@example.test",
            is_anonymous=False,
            api_token="pack-google-token",
        )
        self.anon_user = AppUser.objects.create(
            google_sub="pack-api-anon",
            email="anon@example.test",
            is_anonymous=True,
            api_token="pack-anon-token",
        )

    def test_questions_require_google_account(self):
        from django.urls import reverse

        url = reverse(
            "exam-pack-exam-questions",
            kwargs={"pack_id": self.pack.public_id, "exam_index": 1},
        )
        unauth = self.client.get(url)
        self.assertEqual(unauth.status_code, 401)

        anon = self.client.get(
            url, HTTP_AUTHORIZATION=f"Bearer {self.anon_user.api_token}"
        )
        self.assertEqual(anon.status_code, 401)

        ok = self.client.get(
            url, HTTP_AUTHORIZATION=f"Bearer {self.google_user.api_token}"
        )
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.json()["questionCount"], 1)
