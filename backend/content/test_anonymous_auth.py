"""Firebase anonim + Google giriş testleri."""

from django.test import TestCase
from django.utils import timezone
from datetime import timedelta

from content.auth import guest_email, merge_guest_user_into, upsert_firebase_user
from content.models import AppUser, DailyMiniExamAttempt


class AnonymousAuthTests(TestCase):
    def test_guest_email_format(self):
        email = guest_email("abc123XYZ")
        self.assertTrue(email.endswith("@guest.hedefkamu.app"))
        self.assertIn("anon+", email)

    def test_upsert_anonymous_user(self):
        user = upsert_firebase_user(
            {
                "sub": "anon-firebase-uid-1",
                "email": "",
                "name": "",
                "picture": "",
                "is_anonymous": True,
            }
        )
        self.assertTrue(user.is_anonymous)
        self.assertEqual(user.display_name, "Misafir")
        self.assertTrue(user.email.endswith("@guest.hedefkamu.app"))

    def test_anonymous_upgrade_to_google(self):
        anon = upsert_firebase_user(
            {
                "sub": "linked-uid-1",
                "email": "",
                "is_anonymous": True,
            }
        )
        linked = upsert_firebase_user(
            {
                "sub": "linked-uid-1",
                "email": "student@example.com",
                "name": "Öğrenci",
                "picture": "",
                "is_anonymous": False,
            }
        )
        self.assertEqual(anon.pk, linked.pk)
        self.assertFalse(linked.is_anonymous)
        self.assertEqual(linked.email, "student@example.com")
        self.assertEqual(linked.display_name, "Öğrenci")

    def test_anonymous_upgrade_without_name_replaces_misafir(self):
        anon = upsert_firebase_user(
            {
                "sub": "linked-uid-2",
                "email": "",
                "is_anonymous": True,
            }
        )
        self.assertEqual(anon.display_name, "Misafir")
        linked = upsert_firebase_user(
            {
                "sub": "linked-uid-2",
                "email": "betul@gmail.com",
                "name": "",
                "picture": "",
                "is_anonymous": False,
            }
        )
        self.assertEqual(anon.pk, linked.pk)
        self.assertEqual(linked.display_name, "betul")

    def test_orphan_guest_removed_when_google_uses_different_sub(self):
        guest = upsert_firebase_user(
            {
                "sub": "anon-orphan-uid",
                "email": "",
                "is_anonymous": True,
            }
        )
        guest_pk = guest.pk

        google = upsert_firebase_user(
            {
                "sub": "google-permanent-uid",
                "email": "student@example.com",
                "name": "Öğrenci",
                "is_anonymous": False,
            },
            guest_sub="anon-orphan-uid",
        )

        self.assertFalse(google.is_anonymous)
        self.assertFalse(AppUser.objects.filter(pk=guest_pk).exists())
        self.assertEqual(AppUser.objects.filter(is_anonymous=True).count(), 0)

    def test_same_sub_upgrade_does_not_delete_user(self):
        guest = upsert_firebase_user(
            {
                "sub": "linked-uid-merge",
                "email": "",
                "is_anonymous": True,
            }
        )
        upgraded = upsert_firebase_user(
            {
                "sub": "linked-uid-merge",
                "email": "merge@example.com",
                "name": "Merge",
                "is_anonymous": False,
            },
            guest_sub="linked-uid-merge",
        )
        self.assertEqual(guest.pk, upgraded.pk)
        self.assertFalse(upgraded.is_anonymous)

    def test_merge_guest_moves_mini_exam_attempt(self):
        guest = upsert_firebase_user(
            {
                "sub": "guest-mini-uid",
                "email": "",
                "is_anonymous": True,
            }
        )
        target = upsert_firebase_user(
            {
                "sub": "google-mini-uid",
                "email": "mini@example.com",
                "name": "Mini",
                "is_anonymous": False,
            }
        )
        attempt = DailyMiniExamAttempt.objects.create(
            user=guest,
            exam_date=timezone.localdate(),
            kpss_type="lisans",
            correct=12,
            wrong=5,
            blank=3,
        )
        merge_guest_user_into(guest=guest, target=target)
        attempt.refresh_from_db()
        self.assertEqual(attempt.user_id, target.pk)
        self.assertFalse(AppUser.objects.filter(pk=guest.pk).exists())

    def test_merge_guest_premium_when_target_not_premium(self):
        guest = upsert_firebase_user(
            {
                "sub": "guest-premium-uid",
                "email": "",
                "is_anonymous": True,
            }
        )
        guest.is_premium = True
        guest.premium_expires_at = timezone.now() + timedelta(days=30)
        guest.premium_product_id = "kpss_premium_monthly"
        guest.save()

        target = upsert_firebase_user(
            {
                "sub": "google-premium-uid",
                "email": "premium@example.com",
                "name": "Premium",
                "is_anonymous": False,
            }
        )
        merge_guest_user_into(guest=guest, target=target)
        target.refresh_from_db()
        self.assertTrue(target.premium_active)
        self.assertEqual(target.premium_product_id, "kpss_premium_monthly")
