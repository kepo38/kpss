"""SVG çıkarımı, güvenlik süzgeci ve panel kayıt."""

import tempfile

from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, TestCase
from PIL import Image

from .models import Question, Subject, Topic
from .serializers import QuestionSerializer
from .svg_sanitize import (
    extract_svg,
    is_safe_svg,
    sanitize_figure_svg,
    strip_raster_embeds,
    strip_watermark_marks,
)


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

    def test_strips_embedded_photo_keeps_vectors(self):
        raw = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
            '<image href="data:image/png;base64,iVBORw0KGgo=" width="100" height="100"/>'
            '<polygon points="10,90 90,90 10,10" fill="none" stroke="black"/>'
            "</svg>"
        )
        cleaned = sanitize_figure_svg(raw)
        self.assertIn("<polygon", cleaned)
        self.assertNotIn("data:image", cleaned)
        self.assertNotIn("<image", cleaned.lower())

    def test_photo_only_svg_discarded(self):
        raw = (
            '<svg xmlns="http://www.w3.org/2000/svg">'
            '<image href="data:image/png;base64,abc" width="10" height="10"/>'
            "</svg>"
        )
        self.assertEqual(sanitize_figure_svg(raw), "")
        self.assertEqual(strip_raster_embeds(raw).count("image"), 0)



    def test_strips_osym_text_keeps_geometry(self):
        raw = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
            '<text x="80" y="12">ÖSYM</text>'
            '<polygon points="10,90 90,90 10,10" fill="none" stroke="black"/>'
            '<text x="8" y="98">A</text>'
            "</svg>"
        )
        cleaned = sanitize_figure_svg(raw)
        self.assertIn("<polygon", cleaned)
        self.assertIn(">A<", cleaned)
        self.assertNotRegex(cleaned, r"(?i)ö\s*s\s*y\s*m|osym|ösym")
        self.assertEqual(strip_watermark_marks(raw).lower().count("ösym"), 0)


class CorrectOptionNormalizationTests(SimpleTestCase):
    def test_empty_when_missing(self):
        from .ocr_ingest import normalize_correct_option

        self.assertEqual(normalize_correct_option(""), "")
        self.assertEqual(normalize_correct_option("  "), "")

    def test_keeps_valid_letter(self):
        from .ocr_ingest import normalize_correct_option

        self.assertEqual(normalize_correct_option("c"), "C")
        self.assertEqual(normalize_correct_option(" A "), "A")

    def test_rejects_invalid(self):
        from .ocr_ingest import normalize_correct_option

        self.assertEqual(normalize_correct_option("AB"), "")
        self.assertEqual(normalize_correct_option("1"), "")


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

    def test_publish_without_keep_image_deletes_telegram_photo(self):
        self.client.force_login(self.staff)
        buf = BytesIO()
        Image.new("RGB", (12, 12), "white").save(buf, format="PNG")
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_tg_photo",
            stem="Telegram foto",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
            figure_svg=TRIANGLE,
        )
        question.image.save(
            "tg_scan.png",
            SimpleUploadedFile("tg_scan.png", buf.getvalue(), content_type="image/png"),
            save=True,
        )
        image_name = question.image.name
        storage = question.image.storage
        self.assertTrue(storage.exists(image_name))

        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/{question.id}/",
            self._payload(
                figure_svg=TRIANGLE,
                stem="Telegram foto",
                is_published="on",
            ),
        )
        self.assertEqual(response.status_code, 302)
        question.refresh_from_db()
        self.assertTrue(question.is_published)
        self.assertFalse(question.image)
        self.assertFalse(storage.exists(image_name))

    def test_keep_image_preserves_photo(self):
        self.client.force_login(self.staff)
        buf = BytesIO()
        Image.new("RGB", (10, 10), "blue").save(buf, format="PNG")
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_keep_photo",
            stem="Koru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
        )
        question.image.save(
            "keep.png",
            SimpleUploadedFile("keep.png", buf.getvalue(), content_type="image/png"),
            save=True,
        )
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/{question.id}/",
            self._payload(stem="Koru", keep_image="1", is_published="on"),
        )
        self.assertEqual(response.status_code, 302)
        question.refresh_from_db()
        self.assertTrue(bool(question.image))

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

    def test_panel_save_stores_solution_figure_svg(self):
        self.client.force_login(self.staff)
        marked = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160" '
            'data-geo-editor="1" data-geo-role="solution">'
            '<g data-geo-layer="base">'
            '<polygon points="20,140 180,140 20,20" fill="none" stroke="black"/>'
            "</g>"
            '<g data-geo-layer="overlay">'
            '<circle cx="40" cy="40" r="8" fill="none" stroke="red"/>'
            "</g>"
            "</svg>"
        )
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            self._payload(
                figure_svg=TRIANGLE,
                solution_figure_svg=marked,
                solution="Çözüm [ŞEKİL]",
            ),
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertIn("<svg", question.figure_svg)
        self.assertIn("data-geo-role", question.solution_figure_svg)
        self.assertIn("overlay", question.solution_figure_svg)

    def test_serializer_exposes_sekil_kodu_cozum(self):
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_svg_sol",
            stem="Geometri",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            figure_svg=TRIANGLE,
            solution_figure_svg=TRIANGLE.replace("<svg", '<svg data-geo-role="solution"', 1),
        )
        data = QuestionSerializer(question).data
        self.assertIn("<svg", data["sekilKodu"])
        self.assertIn("data-geo-role", data["sekilKoduCozum"])

    def test_clear_solution_image_discards_existing(self):
        self.client.force_login(self.staff)
        buf = BytesIO()
        Image.new("RGB", (10, 10), "green").save(buf, format="PNG")
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_sol_img",
            stem="Çözüm görseli",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=True,
        )
        question.solution_image.save(
            "sol.png",
            SimpleUploadedFile("sol.png", buf.getvalue(), content_type="image/png"),
            save=True,
        )
        self.assertTrue(bool(question.solution_image))
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/{question.id}/",
            self._payload(
                stem="Çözüm görseli",
                clear_solution_image="1",
                is_published="on",
            ),
        )
        self.assertEqual(response.status_code, 302)
        question.refresh_from_db()
        self.assertFalse(bool(question.solution_image))

    def test_solution_image_untouched_without_clear(self):
        self.client.force_login(self.staff)
        buf = BytesIO()
        Image.new("RGB", (10, 10), "red").save(buf, format="PNG")
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_sol_keep",
            stem="Koru çözüm",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=True,
        )
        question.solution_image.save(
            "keep_sol.png",
            SimpleUploadedFile("keep_sol.png", buf.getvalue(), content_type="image/png"),
            save=True,
        )
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/{question.id}/",
            self._payload(stem="Koru çözüm", is_published="on"),
        )
        self.assertEqual(response.status_code, 302)
        question.refresh_from_db()
        self.assertTrue(bool(question.solution_image))

    def test_geometry_overlay_discarded_when_figure_svg_saved(self):
        """Eski OCR solution_overlay_*, figure_svg varken kaydetmede silinir."""
        self.client.force_login(self.staff)
        buf = BytesIO()
        Image.new("RGB", (10, 10), "blue").save(buf, format="PNG")
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_sol_overlay",
            stem="$|AD| = |DC|$\n$|DB| = |DE|$",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            figure_svg=TRIANGLE,
            is_published=True,
        )
        question.solution_image.save(
            "solution_overlay_q_sol_overlay.png",
            SimpleUploadedFile(
                "solution_overlay_q_sol_overlay.png",
                buf.getvalue(),
                content_type="image/png",
            ),
            save=True,
        )
        self.assertTrue(bool(question.solution_image))
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/{question.id}/",
            self._payload(
                stem=question.stem,
                figure_svg=TRIANGLE,
                is_published="on",
            ),
        )
        self.assertEqual(response.status_code, 302)
        question.refresh_from_db()
        self.assertFalse(bool(question.solution_image))
        self.assertTrue(bool(question.figure_svg))
