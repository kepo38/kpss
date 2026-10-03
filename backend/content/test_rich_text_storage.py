"""Kayıt-tek-yol storage normalizer tests."""

from django.test import SimpleTestCase

from content.models import Question, Subject, Topic
from content.rich_text_storage import (
    normalize_field,
    normalize_question_for_storage,
    question_needs_content_normalize,
)


class RichTextStorageTests(SimpleTestCase):
    def test_normalize_field_routes_solution(self):
        src = "**KPSS Hap Bilgi:** Özet"
        out = normalize_field("solution", src)
        self.assertIn("**KPSS Hap Bilgi:**", out)

    def test_question_needs_content_normalize_detects_block_underline(self):
        subject = Subject(slug="tarih", name="Tarih")
        topic = Topic(subject=subject, slug="genel", name="Genel")
        q = Question(
            topic=topic,
            public_id="q_dirty",
            stem="Soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            solution="__## 1. Adım: Test__\nGövde",
        )
        self.assertTrue(question_needs_content_normalize(q))

    def test_question_needs_content_normalize_clean_after_normalize(self):
        subject = Subject(slug="tarih", name="Tarih")
        topic = Topic(subject=subject, slug="genel", name="Genel")
        q = Question(
            topic=topic,
            public_id="q_clean",
            stem="**Soru** metin",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            solution="**Açıklama:** temiz çözüm",
        )
        normalize_question_for_storage(q)
        self.assertFalse(question_needs_content_normalize(q))

    def test_normalize_question_for_storage_idempotent(self):
        subject = Subject(slug="tarih", name="Tarih")
        topic = Topic(subject=subject, slug="genel", name="Genel")
        q = Question(
            topic=topic,
            public_id="q_test",
            stem="**Soru kökü** metin",
            option_a="**A)** bir",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            solution="__## 1. Adım: Test__\nGövde",
        )
        normalize_question_for_storage(q)
        once_stem = q.stem
        once_solution = q.solution
        normalize_question_for_storage(q)
        self.assertEqual(q.stem, once_stem)
        self.assertEqual(q.solution, once_solution)
        self.assertIn("**1. Adım: Test**", q.solution)
        self.assertNotIn("__##", q.solution)
