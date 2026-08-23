"""Tests for question_diagnosis."""

from django.test import SimpleTestCase, TestCase

from content.models import Question, Subject, Topic
from content.question_diagnosis import diagnose_question_public_id
from content.telegram_panel import telegram_question_ocr_flags


class DiagnoseQuestionNotFoundTests(SimpleTestCase):
    def test_missing_public_id(self):
        diag = diagnose_question_public_id("q_does_not_exist_xyz")
        self.assertFalse(diag.found)
        self.assertIn("Kayit yok", diag.summary_lines[0])


class DiagnoseQuestionFoundTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="turkce", name="Turkce")
        self.topic = Topic.objects.create(
            subject=subject,
            slug="anlam",
            name="Anlam",
        )

    def test_visual_options_flags_c2_c3(self):
        Question.objects.create(
            public_id="q_diag_visual",
            topic=self.topic,
            stem="Aşağıdaki görsele göre cevaplayınız.",
            option_a="Görsel şık",
            option_b="Görsel şık",
            option_c="—",
            option_d="—",
            option_e="—",
            options_are_images=True,
        )
        diag = diagnose_question_public_id("q_diag_visual")
        self.assertTrue(diag.found)
        self.assertIn("C2", diag.priority_codes)
        self.assertIn("C3", diag.priority_codes)

    def test_text_question_risk_score(self):
        Question.objects.create(
            public_id="q_diag_text",
            topic=self.topic,
            stem="",
            option_a="A",
            option_b="B",
            option_c="—",
            option_d="—",
            option_e="—",
        )
        q = Question.objects.get(public_id="q_diag_text")
        flags = telegram_question_ocr_flags(q)
        self.assertGreater(flags.risk_score, 0)
        diag = diagnose_question_public_id("q_diag_text")
        self.assertTrue(diag.c1_text_ocr)
