from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from .models import AppUser, Question, QuestionRating, Subject, Topic


class RatingFixtureMixin:
    def setUp(self):
        self.subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="ilk-turk-devletleri",
            name="İlk Türk Devletleri",
        )
        self.question = Question.objects.create(
            topic=self.topic,
            public_id="q_rating_1",
            stem="Hangisi doğrudur?",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=True,
        )
        self.user = self.make_app_user(1)

    def make_app_user(self, number: int) -> AppUser:
        return AppUser.objects.create(
            google_sub=f"rating-sub-{number}",
            email=f"rating-{number}@example.com",
            display_name=f"Öğrenci {number}",
            api_token=f"rating-token-{number}",
        )

    def auth(self, user: AppUser | None = None) -> dict[str, str]:
        selected = user or self.user
        return {"HTTP_AUTHORIZATION": f"Bearer {selected.api_token}"}


class QuestionRatingApiTests(RatingFixtureMixin, TestCase):
    def url(self, question: Question | None = None) -> str:
        return reverse(
            "question-rating",
            kwargs={"public_id": (question or self.question).public_id},
        )

    def test_authentication_is_required(self):
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 401)

    def test_get_returns_empty_personal_rating_and_aggregate(self):
        response = self.client.get(self.url(), **self.auth())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"userRating": None, "averageRating": None, "ratingCount": 0},
        )

    def test_put_creates_then_updates_single_rating(self):
        created = self.client.put(
            self.url(),
            data={"stars": 2},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(created.status_code, 200)
        self.assertEqual(created.json()["userRating"], 2)
        self.assertEqual(created.json()["averageRating"], 2.0)

        updated = self.client.put(
            self.url(),
            data={"stars": 5},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(QuestionRating.objects.count(), 1)
        rating = QuestionRating.objects.get()
        self.assertEqual(rating.stars, 5)
        self.assertEqual(updated.json()["averageRating"], 5.0)

    def test_put_validates_star_boundaries(self):
        for value in (0, 6, 2.5, "bad", None):
            response = self.client.put(
                self.url(),
                data={"stars": value},
                content_type="application/json",
                **self.auth(),
            )
            self.assertEqual(response.status_code, 400)
        self.assertEqual(QuestionRating.objects.count(), 0)

    def test_aggregate_includes_multiple_students(self):
        other = self.make_app_user(2)
        QuestionRating.objects.create(
            question=self.question,
            user=self.user,
            stars=2,
        )
        QuestionRating.objects.create(
            question=self.question,
            user=other,
            stars=4,
        )

        response = self.client.get(self.url(), **self.auth())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["userRating"], 2)
        self.assertEqual(response.json()["averageRating"], 3.0)
        self.assertEqual(response.json()["ratingCount"], 2)

    def test_unpublished_question_is_not_rateable(self):
        self.question.is_published = False
        self.question.save(update_fields=["is_published"])
        get_response = self.client.get(self.url(), **self.auth())
        put_response = self.client.put(
            self.url(),
            data={"stars": 3},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(get_response.status_code, 404)
        self.assertEqual(put_response.status_code, 404)

    def test_unknown_question_returns_not_found(self):
        url = reverse("question-rating", kwargs={"public_id": "missing"})
        response = self.client.get(url, **self.auth())
        self.assertEqual(response.status_code, 404)


class QualityDashboardTests(RatingFixtureMixin, TestCase):
    def setUp(self):
        super().setUp()
        self.staff = get_user_model().objects.create_user(
            username="quality-staff",
            password="x",
            is_staff=True,
        )
        self.client.force_login(self.staff)

    def add_ratings(self, question: Question, stars: int, count: int):
        start = AppUser.objects.count() + 1
        for index in range(start, start + count):
            QuestionRating.objects.create(
                question=question,
                user=self.make_app_user(index),
                stars=stars,
            )

    def test_default_dashboard_requires_ten_votes(self):
        self.add_ratings(self.question, stars=1, count=9)
        response = self.client.get(reverse("panel_quality"))
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, self.question.public_id)

        QuestionRating.objects.create(
            question=self.question,
            user=self.user,
            stars=1,
        )
        response = self.client.get(reverse("panel_quality"))
        self.assertContains(response, self.question.public_id)

    def test_dashboard_excludes_unpublished_questions(self):
        self.add_ratings(self.question, stars=1, count=10)
        self.question.is_published = False
        self.question.save(update_fields=["is_published"])

        response = self.client.get(reverse("panel_quality"))
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, self.question.public_id)

    def test_dashboard_filters_by_subject_and_max_average(self):
        geography = Subject.objects.create(slug="cografya", name="Coğrafya")
        geography_topic = Topic.objects.create(
            subject=geography,
            slug="harita",
            name="Harita Bilgisi",
        )
        geography_question = Question.objects.create(
            topic=geography_topic,
            public_id="q_rating_geo",
            stem="Coğrafya sorusu",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=True,
        )
        self.add_ratings(self.question, stars=2, count=10)
        self.add_ratings(geography_question, stars=4, count=10)

        response = self.client.get(
            reverse("panel_quality"),
            {"subject": self.subject.id, "max_rating": "2.5", "min_votes": "10"},
        )
        self.assertContains(response, self.question.public_id)
        self.assertNotContains(response, geography_question.public_id)

    def test_invalid_numeric_filters_fall_back_without_crashing(self):
        response = self.client.get(
            reverse("panel_quality"),
            {"min_votes": "nan", "max_rating": "infinity"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'value="2.5"')
        self.assertContains(response, 'value="10"')


class QuestionRatingAdminTests(RatingFixtureMixin, TestCase):
    def setUp(self):
        super().setUp()
        self.admin_user = get_user_model().objects.create_superuser(
            username="rating-admin",
            password="x",
            email="admin@example.com",
        )
        self.client.force_login(self.admin_user)

    def test_question_list_can_filter_low_rated_questions_with_ten_votes(self):
        for index in range(10):
            QuestionRating.objects.create(
                question=self.question,
                user=self.make_app_user(index + 10),
                stars=1,
            )

        response = self.client.get(
            reverse("admin:content_question_changelist"),
            {"rating_band": "1", "min_votes": "10"},
        )
        self.assertEqual(response.status_code, 200)
        result_list = list(response.context["cl"].result_list)
        self.assertEqual(result_list, [self.question])
        self.assertEqual(result_list[0]._rating_average, 1.0)
        self.assertEqual(result_list[0]._rating_count, 10)
