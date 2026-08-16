"""SVG çıkarımı, güvenlik süzgeci ve panel kayıt."""

import tempfile

from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, TestCase
from PIL import Image

from .models import Question, Subject, Topic
from .serializers import QuestionSerializer
from .svg_sanitize import extract_svg, is_safe_svg


TRIANGLE = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160">'
    '<polygon points="20,140 180,140 20,20" fill="none" stroke="black"/>'
    '<text x="12" y="152">A</text>'
    '<text x="182" y="152">B</text>'
    '<text x="8" y="16">C</text>'
    '<path d="M28 140 L28 128 L40 128" fill="none" stroke="black"/>'
    '<text x="52" y="132">90°</text>'
    "</svg>"
)


class SvgExtractTests(SimpleTestCase):
    def test_extracts_svg_block(self):
        raw = "ön\n" + TRIANGLE + "\nson"
        self.assertEqual(extract_svg(raw), TRIANGLE)

    def test_strips_markdown_fence(self):
        raw = "```svg\n" + TRIANGLE + "\n```"
        self.assertEqual(extract_svg(raw), TRIANGLE)

    def test_rejects_script(self):
        raw = '<svg><script>alert(1)</script><rect x="0" y="0" width="1" height="1"/></svg>'
        self.assertFalse(is_safe_svg(raw))

    def test_rejects_external_href(self):
        raw = (
            '<svg xmlns="http://www.w3.org/2000/svg">'
            '<image href="https://evil.test/x.png" width="10" height="10"/>'
            "</svg>"
        )
        self.assertFalse(is_safe_svg(raw))

    def test_accepts_triangle(self):
        self.assertTrue(is_safe_svg(TRIANGLE))


class FigureSvgPanelTests(TestCase):
    def setUp(self):
        self.media_dir = tempfile.TemporaryDirectory()
        self.settings_override = self.settings(MEDIA_ROOT=self.media_dir.name)
        self.settings_override.enable()
        self.addCleanup(self.settings_override.disable)
        self.addCleanup(self.media_dir.cleanup)

        self.subject = Subject.objects.create(slug="matematik", name="Matematik")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="geometri",
            name="Geometri",
        )
        self.staff = get_user_model().objects.create_user(
            username="svg_staff",
            password="x",
            is_staff=True,
        )

    def _payload(self, **extra) -> dict:
        data = {
            "topic_id": str(self.topic.id),
            "stem": "ABC dik üçgeninde x kaçtır?",
            "option_a": "40",
            "option_b": "50",
            "option_c": "60",
            "option_d": "70",
            "option_e": "80",
            "correct_option": "A",
            "test_assignment": "auto",
            "is_published": "on",
            "map_template": "",
            "map_markers": "[]",
        }
        data.update(extra)
        return data

    def test_panel_save_stores_svg_without_raster_image(self):
        self.client.force_login(self.staff)
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            self._payload(figure_svg=TRIANGLE),
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertIn("<svg", question.figure_svg)
        self.assertFalse(question.image)

    def test_panel_save_discards_ocr_upload_even_with_svg(self):
        self.client.force_login(self.staff)
        buf = BytesIO()
        Image.new("RGB", (8, 8), "white").save(buf, format="PNG")
        upload = SimpleUploadedFile(
            "sekil.png", buf.getvalue(), content_type="image/png"
        )
        payload = self._payload(figure_svg=TRIANGLE)
        payload["image"] = upload
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            payload,
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertIn("<svg", question.figure_svg)
        self.assertFalse(question.image)

    def test_unsafe_svg_is_discarded(self):
        self.client.force_login(self.staff)
        unsafe = '<svg><script>alert(1)</script><rect x="0" y="0" width="1" height="1"/></svg>'
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            self._payload(figure_svg=unsafe),
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertEqual(question.figure_svg, "")

    def test_serializer_exposes_sekil_kodu(self):
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_svg_serializer",
            stem="Geometri",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            figure_svg=TRIANGLE,
        )
        data = QuestionSerializer(question).data
        self.assertIn("<svg", data["sekilKodu"])
