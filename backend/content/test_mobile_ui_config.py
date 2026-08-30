from django.test import TestCase
from django.urls import reverse

from content.models import get_mobile_ui_config


class MobileUiConfigApiTests(TestCase):
    def test_get_returns_default_config(self):
        response = self.client.get(reverse("mobile-ui"))
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("wrongNotebookBubbleEnabled", body)
        self.assertIn("wrongNotebookBubbleLabel", body)
        self.assertIn("bannerAdsEnabled", body)
        self.assertIn("studioModules", body)
        self.assertIn("recommendedAppVersion", body)
        self.assertIn("updatedAt", body)
        self.assertEqual(body["recommendedAppVersion"], "")
        self.assertIsInstance(body["studioModules"], dict)

    def test_get_reflects_recommended_app_version(self):
        cfg = get_mobile_ui_config()
        cfg.recommended_app_version = "1.0.2"
        cfg.save()

        response = self.client.get(reverse("mobile-ui"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["recommendedAppVersion"], "1.0.2")
