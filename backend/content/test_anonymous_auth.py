"""Firebase anonim + Google giriş testleri."""

from django.test import TestCase

from content.auth import guest_email, upsert_firebase_user


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
