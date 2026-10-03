from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase
from django.utils import timezone

from content.models import TgExam
from content.tg_exam.announcements import (
    TG_EXAM_PUSH_CHANNEL,
    TG_EXAM_PUSH_COLOR,
    build_announcement_push_copy,
    build_announcement_push_payload,
    build_results_push_copy,
)


class TgExamAnnouncementCopyTests(TestCase):
    def setUp(self):
        now = timezone.now()
        self.exam = TgExam.objects.create(
            title="[DEMO] TG Deneme · lisans",
            kpss_type="lisans",
            start_at=now + timedelta(hours=2),
            end_at=now + timedelta(hours=4),
            question_ids=[f"q{i}" for i in range(120)],
            is_published=True,
        )

    def test_announcement_copy_uses_exam_title_and_clean_body(self):
        title, body = build_announcement_push_copy(self.exam)
        self.assertEqual(title, "[DEMO] TG Deneme · lisans")
        self.assertIn("2 saat sonra başlıyor", body)
        self.assertIn("Yerini ayırt", body)
        self.assertNotIn("「", body)

    def test_announcement_payload_includes_premium_fields(self):
        payload = build_announcement_push_payload(self.exam)
        self.assertEqual(payload["headline"], "Türkiye Geneli Deneme")
        self.assertEqual(payload["exam_title"], "[DEMO] TG Deneme · lisans")
        self.assertIn("120 soru", payload["metrics_label"])
        self.assertIn("130 dk", payload["metrics_label"])
        self.assertEqual(payload["cta_hint"], "Denemeye git →")

    def test_results_copy_is_premium_and_specific(self):
        title, body = build_results_push_copy(self.exam)
        self.assertIn("[DEMO] TG Deneme · lisans", title)
        self.assertIn("Sonuçların hazır", title)
        self.assertIn("sıralaman", body.lower())

    @patch("content.push._tg_exam_push_banner_url", return_value="https://cdn.example/banner.jpg")
    def test_push_data_includes_style_and_image(self, _banner):
        from content.push import _tg_exam_push_data

        payload = build_announcement_push_payload(self.exam)
        data = _tg_exam_push_data(
            push_type="tg_exam",
            exam=self.exam,
            payload=payload,
        )
        self.assertEqual(data["type"], "tg_exam")
        self.assertEqual(data["style"], "tg_exam_premium")
        self.assertEqual(data["image_url"], "https://cdn.example/banner.jpg")
        self.assertEqual(data["exam_title"], "[DEMO] TG Deneme · lisans")

    def test_channel_and_color_constants(self):
        self.assertEqual(TG_EXAM_PUSH_CHANNEL, "tg_exams")
        self.assertEqual(TG_EXAM_PUSH_COLOR, "#C41E3A")
