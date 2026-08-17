from django.test import TestCase

from .models import AppUser, Question, QuestionAttempt, Subject, Topic, TopicTest


class QuestionDifficultyTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="mat", name="Matematik")
        self.topic = Topic.objects.create(
            subject=subject, slug="sayi", name="Sayılar"
        )
        self.question = Question.objects.create(
            public_id="q_difficulty_1",
            topic=self.topic,
            stem="Örnek zorluk sorusu",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            correct_option="A",
            is_published=True,
        )

    def _user(self, suffix: str) -> AppUser:
        return AppUser.objects.create(
            google_sub=f"difficulty-{suffix}",
            email=f"{suffix}@example.test",
        )

    def test_new_question_is_medium_and_hidden_before_threshold(self):
        self.assertEqual(self.question.difficulty, Question.DIFFICULTY_MEDIUM)
        self.assertFalse(self.question.difficulty_visible)

    def test_80_percent_correct_becomes_easy_at_threshold(self):
        self.question.attempt_count = 999
        self.question.correct_count = 799
        self.question.wrong_count = 200
        self.question.save()

        QuestionAttempt.record_first_answer(
            question=self.question,
            user=self._user("easy"),
            outcome=QuestionAttempt.OUTCOME_CORRECT,
            selected_option="A",
        )
        self.question.refresh_from_db()
        self.assertEqual(self.question.attempt_count, 1000)
        self.assertEqual(self.question.difficulty, Question.DIFFICULTY_EASY)
        self.assertTrue(self.question.difficulty_visible)

    def test_70_percent_non_correct_becomes_hard_at_threshold(self):
        self.question.attempt_count = 999
        self.question.correct_count = 300
        self.question.wrong_count = 699
        self.question.save()

        QuestionAttempt.record_first_answer(
            question=self.question,
            user=self._user("hard"),
            outcome=QuestionAttempt.OUTCOME_BLANK,
        )
        self.question.refresh_from_db()
        self.assertEqual(self.question.difficulty, Question.DIFFICULTY_HARD)

    def test_second_answer_from_same_user_is_ignored(self):
        user = self._user("once")
        self.assertTrue(
            QuestionAttempt.record_first_answer(
                question=self.question,
                user=user,
                outcome=QuestionAttempt.OUTCOME_CORRECT,
                selected_option="A",
            )
        )
        self.assertFalse(
            QuestionAttempt.record_first_answer(
                question=self.question,
                user=user,
                outcome=QuestionAttempt.OUTCOME_WRONG,
                selected_option="B",
            )
        )
        self.question.refresh_from_db()
        self.assertEqual(self.question.attempt_count, 1)
        self.assertEqual(self.question.correct_count, 1)
        self.assertEqual(self.question.wrong_count, 0)

    def test_attempt_endpoint_grades_test_questions_server_side(self):
        test = TopicTest.objects.create(
            public_id="test_difficulty_1",
            topic=self.topic,
            title="Zorluk testi",
            is_published=True,
        )
        test.questions.add(self.question)
        user = self._user("api")
        user.api_token = "difficulty-api-token"
        user.save(update_fields=["api_token"])

        response = self.client.post(
            f"/api/v1/tests/{test.public_id}/attempt/",
            data={"answers": {self.question.public_id: "A"}},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user.api_token}",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["accepted"], 1)
        self.question.refresh_from_db()
        self.assertEqual(self.question.correct_count, 1)

    def test_single_attempt_returns_option_statistics(self):
        test = TopicTest.objects.create(
            public_id="test_option_stats",
            topic=self.topic,
            title="Şık istatistik testi",
            is_published=True,
        )
        test.questions.add(self.question)
        user = self._user("options")
        user.api_token = "option-stats-token"
        user.save(update_fields=["api_token"])

        response = self.client.post(
            f"/api/v1/questions/{self.question.public_id}/attempt/",
            data={"testId": test.public_id, "selectedOption": "A"},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user.api_token}",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["accepted"])
        self.assertEqual(response.json()["solvedCount"], 1)
        self.assertIsNone(response.json()["optionPercentages"])
        self.question.refresh_from_db()
        self.assertEqual(self.question.option_a_count, 1)
