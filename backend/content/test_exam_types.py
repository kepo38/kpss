from datetime import date

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from content.models import ExamType


class ExamTypeApiTests(TestCase):
    def test_seeded_types_are_listed(self):
        response = self.client.get(reverse("exam-types"))
        self.assertEqual(response.status_code, 200)
        slugs = {item["id"] for item in response.json()["examTypes"]}
        self.assertIn("kpssLisans", slugs)
        self.assertIn("ags", slugs)
        self.assertIn("ales", slugs)
        self.assertIn("dgs", slugs)

    def test_on_lisans_and_ortaogretim_are_even_years_only(self):
        response = self.client.get(reverse("exam-types"))
        by_id = {item["id"]: item for item in response.json()["examTypes"]}
        self.assertTrue(by_id["kpssOnLisans"]["evenYearsOnly"])
        self.assertTrue(by_id["kpssOrtaogretim"]["evenYearsOnly"])
        self.assertFalse(by_id["kpssLisans"]["evenYearsOnly"])
        self.assertFalse(by_id["ags"]["evenYearsOnly"])
        self.assertFalse(by_id["ales"]["yearlyRepeat"])
        self.assertFalse(by_id["dgs"]["yearlyRepeat"])

    def test_new_type_appears_in_api(self):
        ExamType.objects.create(
            slug="yds",
            name="YDS",
            short_name="YDS",
            description="Yabancı Dil Bilgisi",
            exam_date=date(2026, 11, 15),
            content_type="lisans",
            icon_key="star",
            sort_order=50,
        )
        response = self.client.get(reverse("exam-types"))
        yds = next(
            item for item in response.json()["examTypes"] if item["id"] == "yds"
        )
        self.assertEqual(yds["examDate"], "2026-11-15")
        self.assertEqual(yds["name"], "YDS")

    def test_inactive_type_is_hidden(self):
        ExamType.objects.filter(slug="ags").update(is_active=False)
        response = self.client.get(reverse("exam-types"))
        slugs = {item["id"] for item in response.json()["examTypes"]}
        self.assertNotIn("ags", slugs)


class ExamTypePanelTests(TestCase):
    def setUp(self):
        user = get_user_model().objects.create_user(
            username="staff",
            password="x",
            is_staff=True,
        )
        self.client.force_login(user)

    def test_list_shows_seeded_types(self):
        response = self.client.get(reverse("panel_exam_type_list"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "KPSS Lisans")
        self.assertContains(response, "AGS")

    def test_create_new_type(self):
        response = self.client.post(
            reverse("panel_exam_type_new"),
            {
                "name": "YDS",
                "short_name": "YDS",
                "slug": "yds",
                "description": "Yabancı Dil Bilgisi",
                "exam_date": "2026-11-15",
                "content_type": "lisans",
                "icon_key": "star",
                "sort_order": "50",
                "yearly_repeat": "on",
                "is_active": "on",
            },
        )
        self.assertEqual(response.status_code, 302)
        item = ExamType.objects.get(slug="yds")
        self.assertEqual(item.exam_date, date(2026, 11, 15))
        api = self.client.get(reverse("exam-types"))
        slugs = {row["id"] for row in api.json()["examTypes"]}
        self.assertIn("yds", slugs)

    def test_update_exam_date(self):
        item = ExamType.objects.get(slug="ags")
        response = self.client.post(
            reverse("panel_exam_type_edit", args=[item.pk]),
            {
                "name": item.name,
                "short_name": item.short_name,
                "slug": item.slug,
                "description": item.description,
                "exam_date": "2027-07-26",
                "content_type": item.content_type,
                "icon_key": item.icon_key,
                "sort_order": str(item.sort_order),
                "yearly_repeat": "on",
                "is_active": "on",
            },
        )
        self.assertEqual(response.status_code, 302)
        item.refresh_from_db()
        self.assertEqual(item.exam_date, date(2027, 7, 26))
