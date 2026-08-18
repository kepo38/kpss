from datetime import timedelta

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from content.models import AppUser, PromoCode, PromoCodeRedemption, normalize_promo_code
from content.promo import PromoError, redeem_promo_code


class PromoCodeModelTests(TestCase):
    def test_code_normalizes_on_save(self):
        promo = PromoCode.objects.create(
            code="  kpss-2026 ",
            max_redemptions=10,
            premium_duration_days=30,
            valid_until=timezone.now() + timedelta(days=30),
        )
        self.assertEqual(promo.code, "KPSS-2026")

    def test_normalize_truncates_to_32(self):
        self.assertEqual(len(normalize_promo_code("A" * 80)), 32)


class PromoRedeemServiceTests(TestCase):
    def setUp(self):
        self.user = AppUser.objects.create(
            google_sub="promo-user-1",
            email="promo@test.com",
            display_name="Promo User",
            api_token="promo-token-1",
        )
        self.other = AppUser.objects.create(
            google_sub="promo-user-2",
            email="other@test.com",
            display_name="Other",
            api_token="promo-token-2",
        )
        now = timezone.now()
        self.promo = PromoCode.objects.create(
            code="HEDEF30",
            title="Launch",
            max_redemptions=2,
            premium_duration_days=30,
            valid_from=now - timedelta(hours=1),
            valid_until=now + timedelta(days=7),
        )

    def test_redeem_grants_premium(self):
        result = redeem_promo_code(user=self.user, raw_code="hedef30")
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_premium)
        self.assertIsNotNone(self.user.premium_expires_at)
        self.assertIn("Promo: HEDEF30", self.user.premium_grant_note)
        self.assertEqual(result.promo_code.code, "HEDEF30")
        self.assertEqual(PromoCodeRedemption.objects.count(), 1)

    def test_rejects_duplicate_user(self):
        redeem_promo_code(user=self.user, raw_code="HEDEF30")
        with self.assertRaises(PromoError) as ctx:
            redeem_promo_code(user=self.user, raw_code="HEDEF30")
        self.assertIn("zaten", ctx.exception.message.lower())

    def test_rejects_when_quota_full(self):
        redeem_promo_code(user=self.user, raw_code="HEDEF30")
        redeem_promo_code(user=self.other, raw_code="HEDEF30")
        third = AppUser.objects.create(
            google_sub="promo-user-3",
            email="third@test.com",
            api_token="promo-token-3",
        )
        with self.assertRaises(PromoError) as ctx:
            redeem_promo_code(user=third, raw_code="HEDEF30")
        self.assertIn("kota", ctx.exception.message.lower())

    def test_rejects_expired_code(self):
        self.promo.valid_until = timezone.now() - timedelta(minutes=1)
        self.promo.save(update_fields=["valid_until"])
        with self.assertRaises(PromoError):
            redeem_promo_code(user=self.user, raw_code="HEDEF30")


class PromoRedeemApiTests(TestCase):
    def setUp(self):
        self.user = AppUser.objects.create(
            google_sub="promo-api-1",
            email="api@test.com",
            api_token="promo-api-token",
        )
        PromoCode.objects.create(
            code="API30",
            max_redemptions=5,
            premium_duration_days=14,
            valid_until=timezone.now() + timedelta(days=3),
        )
        self.url = reverse("promo-redeem")

    def auth(self):
        return {"HTTP_AUTHORIZATION": f"Bearer {self.user.api_token}"}

    def test_redeem_via_api(self):
        response = self.client.post(
            self.url,
            data={"code": "api30"},
            content_type="application/json",
            **self.auth(),
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["ok"])
        self.assertEqual(body["code"], "API30")
        self.assertTrue(body["user"]["isPremium"])

    def test_requires_auth(self):
        response = self.client.post(
            self.url,
            data={"code": "API30"},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)
