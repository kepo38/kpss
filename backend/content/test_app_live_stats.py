from datetime import timedelta

from django.test import TestCase
from django.utils import timezone

from content.app_live_stats import collect_app_live_stats
from content.models import AppUser, DeviceToken


class AppLiveStatsTests(TestCase):
    def test_collect_counts_installs_premium_and_active(self):
        now = timezone.now()
        premium = AppUser.objects.create(
            google_sub="sub-premium",
            email="p@example.com",
            display_name="Premium",
            api_token="tok-premium-1",
            is_premium=True,
            premium_product_id="kpss_premium_yearly",
            last_active_at=now,
        )
        AppUser.objects.create(
            google_sub="sub-guest",
            email="",
            display_name="Misafir",
            api_token="tok-guest-1",
            is_anonymous=True,
            last_active_at=now - timedelta(hours=2),
        )
        DeviceToken.objects.create(
            user=premium,
            token="fcm-device-1",
            platform="android",
            is_active=True,
        )
        DeviceToken.objects.create(
            token="fcm-orphan-1",
            platform="android",
            is_active=True,
            last_seen_at=now,
        )

        stats = collect_app_live_stats()
        self.assertEqual(stats.install_devices, 2)
        self.assertEqual(stats.total_users, 2)
        self.assertEqual(stats.account_users, 1)
        self.assertEqual(stats.guest_users, 1)
        self.assertEqual(stats.premium_users, 1)
        self.assertEqual(stats.premium_yearly, 1)
        self.assertGreaterEqual(stats.active_now, 1)
        self.assertGreaterEqual(stats.active_24h, 1)
