from django.test import SimpleTestCase
from django.urls import reverse


class PrivacyPolicyPageTests(SimpleTestCase):
    def test_privacy_policy_page_renders(self):
        response = self.client.get(reverse("privacy_policy"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Gizlilik Politikası")
        self.assertContains(response, "Hedef Kamu")
        self.assertContains(response, "KVKK")

    def test_english_alias_redirects(self):
        response = self.client.get("/privacy-policy/")
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, "/gizlilik-politikasi/")
