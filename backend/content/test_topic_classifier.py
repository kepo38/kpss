from django.test import TestCase

from content.models import Subject, Topic
from content.topic_classifier import classify_topic_from_ocr, invalidate_topic_cache


class TopicClassifierTests(TestCase):
    def setUp(self):
        invalidate_topic_cache()
        self.turkce = Subject.objects.create(slug="turkce", name="Türkçe")
        self.tarih = Subject.objects.create(slug="tarih", name="Tarih")
        self.matematik = Subject.objects.create(slug="matematik", name="Matematik")
        self.turkce_anlam = Topic.objects.create(
            subject=self.turkce,
            slug="turkce_anlam",
            name="Sözcükte Anlam",
        )
        self.tarih_padisah = Topic.objects.create(
            subject=self.tarih,
            slug="tarih_padisah_antlasma",
            name="Padişahlar ve Antlaşmalar",
        )
        self.mat_geometri = Topic.objects.create(
            subject=self.matematik,
            slug="mat_geometri",
            name="Temel Geometri",
        )

    def test_adaletname_classified_as_history(self):
        stem = (
            "Adaletnâme ile ilgili aşağıdaki ifadelerden hangisi yanlıştır?\n"
            "I. Padişah adaletnâme ile adaleti sağlamayı amaçlar.\n"
            "II. Adaletnâme bir antlaşma metnidir."
        )
        result = classify_topic_from_ocr(
            stem,
            {"A": "Yalnız I", "B": "Yalnız II", "C": "I ve II", "D": "II ve III", "E": "I, II ve III"},
            fallback=self.turkce_anlam,
        )
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.topic.subject.slug, "tarih")
        self.assertNotEqual(result.topic.slug, "turkce_anlam")

    def test_gemini_topic_slug_hint_wins(self):
        result = classify_topic_from_ocr(
            "Herhangi bir metin",
            {},
            topic_slug_hint="mat_geometri",
            fallback=self.turkce_anlam,
        )
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.topic.slug, "mat_geometri")
        self.assertEqual(result.source, "panel_slug")

    def test_invalid_gemini_slug_ignored(self):
        result = classify_topic_from_ocr(
            "Adaletnâme ile ilgili ifadelerden hangisi yanlıştır?",
            {"A": "I", "B": "II", "C": "III", "D": "IV", "E": "V"},
            topic_slug_hint="nonexistent_panel_topic",
            fallback=self.turkce_anlam,
        )
        self.assertIsNotNone(result)
        assert result is not None
        self.assertNotEqual(result.topic.slug, "nonexistent_panel_topic")
        self.assertEqual(result.topic.subject.slug, "tarih")

    def test_catalog_lists_only_panel_topics(self):
        from content.topic_classifier import panel_topic_catalog_text

        catalog = panel_topic_catalog_text()
        self.assertIn("tarih_padisah_antlasma", catalog)
        self.assertIn("turkce_anlam", catalog)
        self.assertNotIn("nonexistent_panel_topic", catalog)

    def test_geometry_keywords(self):
        stem = "ABC eşkenar üçgende A açısı 60° ise B açısı kaç derecedir?"
        result = classify_topic_from_ocr(
            stem,
            {"A": "30", "B": "45", "C": "60", "D": "90", "E": "120"},
            fallback=self.turkce_anlam,
        )
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.topic.subject.slug, "matematik")
