from django.test import TestCase
from rest_framework.test import APIClient

from content.models import AppUser, DailySubjectFreeUsage, Subject, Topic, TopicTest


class DailyQuotaApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = AppUser.objects.create(
            email="quota@example.com",
            display_name="Quota User",
            google_sub="quota-sub-1",
            api_token="quota-token-1",
            is_anonymous=False,
        )
        self.subject = Subject.objects.create(slug="turkce", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="anlam",
            name="Anlam",
        )
        self.test = TopicTest.objects.create(
            topic=self.topic,
            public_id="test-quota-1",
            title="Test 1",
            is_published=True,
        )

    def _auth(self):
        self.client.credentials(HTTP_AUTHORIZATION="Bearer quota-token-1")

    def test_get_empty_then_consume(self):
        self._auth()
        res = self.client.get("/api/v1/daily-quota/", {"subject": "turkce"})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["subjects"]["turkce"]["freeUsed"], 0)

        res = self.client.post(
            "/api/v1/daily-quota/",
            {"subject": "turkce"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["freeUsed"], 1)
        self.assertTrue(body["created"])

        res = self.client.post(
            "/api/v1/daily-quota/",
            {"subject": "turkce"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["freeUsed"], 1)
        self.assertFalse(res.json()["created"])
        self.assertEqual(
            DailySubjectFreeUsage.objects.filter(
                user=self.user,
                subject_slug="turkce",
            ).count(),
            1,
        )

    def test_guest_rejected(self):
        guest = AppUser.objects.create(
            email="",
            display_name="Misafir",
            google_sub="guest-1",
            api_token="guest-token",
            is_anonymous=True,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {guest.api_token}")
        res = self.client.get("/api/v1/daily-quota/")
        self.assertEqual(res.status_code, 401)

    def test_premium_skips_consume(self):
        self.user.is_premium = True
        self.user.premium_expires_at = None
        self.user.save(update_fields=["is_premium", "premium_expires_at"])
        self._auth()
        res = self.client.post(
            "/api/v1/daily-quota/",
            {"subject": "turkce"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json().get("skippedPremium"))
        self.assertEqual(DailySubjectFreeUsage.objects.count(), 0)
