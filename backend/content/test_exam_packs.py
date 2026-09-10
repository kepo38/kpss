from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from content.models import ExamPack, ExamType, Subject


class ExamPackPanelTests(TestCase):
    def setUp(self):
        user = get_user_model().objects.create_user(
            username="staff",
            password="x",
            is_staff=True,
        )
        self.client.force_login(user)
        self.exam_type = ExamType.objects.create(
            slug="kpss_pack_panel",
            name="KPSS Panel",
            exam_date="2026-07-12",
        )
        self.subject = Subject.objects.create(slug="tarih_pack", name="Tarih")
        self.pack = ExamPack.objects.create(
            public_id="ep_panel_tarih",
            exam_type=self.exam_type,
            pack_kind=ExamPack.PACK_KIND_BRANCH,
            subject=self.subject,
            title="Tarih 10lu",
            exam_count=10,
            is_published=False,
        )

    def test_list_has_edit_delete_and_toggle(self):
        response = self.client.get(reverse("panel_exam_pack_list"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Tarih 10lu")
        self.assertContains(response, "Pasif")
        self.assertContains(response, "Aktifleştir")
        self.assertContains(response, "Düzenle")
        self.assertContains(response, "Sil")

    def test_toggle_publishes_and_hides_from_api(self):
        toggle = reverse("panel_exam_pack_toggle", args=[self.pack.pk])
        response = self.client.post(toggle)
        self.assertEqual(response.status_code, 302)
        self.pack.refresh_from_db()
        self.assertTrue(self.pack.is_published)

        api = self.client.get(reverse("exam-packs"))
        titles = {row["title"] for row in api.json()["packs"]}
        self.assertIn("Tarih 10lu", titles)

        self.client.post(toggle)
        self.pack.refresh_from_db()
        self.assertFalse(self.pack.is_published)
        api = self.client.get(reverse("exam-packs"))
        titles = {row["title"] for row in api.json()["packs"]}
        self.assertNotIn("Tarih 10lu", titles)

    def test_edit_updates_title(self):
        response = self.client.post(
            reverse("panel_exam_pack_edit", args=[self.pack.pk]),
            {
                "action": "save",
                "title": "Tarih 20li",
                "description": "",
                "exam_type": str(self.exam_type.pk),
                "pack_kind": ExamPack.PACK_KIND_BRANCH,
                "subject": str(self.subject.pk),
                "exam_count": "10",
                "time_limit_minutes": "130",
                "price_display": "149,99 ₺",
                "play_product_id": "",
                "sort_order": "0",
                "is_published": "on",
            },
        )
        self.assertEqual(response.status_code, 302)
        self.pack.refresh_from_db()
        self.assertEqual(self.pack.title, "Tarih 20li")
        self.assertTrue(self.pack.is_published)

    def test_delete_removes_pack(self):
        response = self.client.post(
            reverse("panel_exam_pack_delete", args=[self.pack.pk]),
        )
        self.assertEqual(response.status_code, 302)
        self.assertFalse(ExamPack.objects.filter(pk=self.pack.pk).exists())

    def test_api_lists_by_content_type_for_non_kpss_exam_type(self):
        ags, _ = ExamType.objects.get_or_create(
            slug="ags_api_pack",
            defaults={
                "name": "AGS",
                "exam_date": "2026-07-26",
                "content_type": "lisans",
            },
        )
        kpss = ExamType.objects.create(
            slug="kpssLisans_pack_test",
            name="KPSS Lisans",
            exam_date="2026-09-06",
            content_type="lisans",
        )
        self.pack.is_published = True
        self.pack.exam_type = kpss
        self.pack.save()

        api = self.client.get(reverse("exam-packs"), {"exam_type": ags.slug})
        self.assertEqual(api.status_code, 200)
        titles = {row["title"] for row in api.json()["packs"]}
        self.assertIn(self.pack.title, titles)
