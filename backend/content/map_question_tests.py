import json
import tempfile
from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.core.files.base import ContentFile
from django.test import RequestFactory, SimpleTestCase, TestCase
from PIL import Image

from .map_question_renderer import render_map_question, validate_map_markers
from .models import Question, Subject, Topic
from .serializers import QuestionSerializer


VALID_MARKERS = [
    {
        "x": 42.5,
        "y": 50,
        "width": 5,
        "height": 4,
        "color": "#ef4444",
        "labelSide": "right",
    },
    {
        "x": 89,
        "y": 50,
        "width": 5,
        "height": 4,
        "color": "#22c55e",
        "labelSide": "left",
    },
]


class MapMarkerValidationTests(SimpleTestCase):
    def test_normalizes_valid_markers(self):
        result = validate_map_markers("turkiye_goller", VALID_MARKERS)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["x"], 42.5)
        self.assertEqual(result[1]["labelSide"], "left")

    def test_rejects_out_of_bounds_coordinate(self):
        invalid = [dict(VALID_MARKERS[0], x=101)]
        with self.assertRaises(ValidationError):
            validate_map_markers("turkiye_goller", invalid)

    def test_ignores_markers_without_template(self):
        result = validate_map_markers("", VALID_MARKERS)
        self.assertEqual(result, [])
        self.assertEqual(validate_map_markers("", "[]"), [])


class MapRendererTests(SimpleTestCase):
    def test_renders_png_with_template_dimensions(self):
        raw = render_map_question("turkiye_goller", VALID_MARKERS)
        with Image.open(BytesIO(raw)) as image:
            self.assertEqual(image.format, "PNG")
            self.assertEqual(image.size, (1600, 700))

    def test_renders_static_map_without_markers(self):
        raw = render_map_question("turkiye_indirgenmis_sicaklik", [])
        with Image.open(BytesIO(raw)) as image:
            self.assertEqual(image.format, "PNG")
            self.assertEqual(image.size, (592, 275))


class MapQuestionPanelTests(TestCase):
    def setUp(self):
        self.media_dir = tempfile.TemporaryDirectory()
        self.settings_override = self.settings(MEDIA_ROOT=self.media_dir.name)
        self.settings_override.enable()
        self.addCleanup(self.settings_override.disable)
        self.addCleanup(self.media_dir.cleanup)

        self.subject = Subject.objects.create(slug="cografya", name="Coğrafya")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="turkiye-fiziki",
            name="Türkiye'nin Fiziki Özellikleri",
        )
        self.staff = get_user_model().objects.create_user(
            username="map_staff",
            password="x",
            is_staff=True,
        )

    def _payload(self) -> dict:
        return {
            "topic_id": str(self.topic.id),
            "stem": "Haritada numaralanmış göller hangileridir?",
            "option_a": "Tuz Gölü - Van Gölü",
            "option_b": "Beyşehir Gölü - Tuz Gölü",
            "option_c": "Van Gölü - Eğirdir Gölü",
            "option_d": "İznik Gölü - Van Gölü",
            "option_e": "Manyas Gölü - Tuz Gölü",
            "correct_option": "A",
            "solution": "I Tuz Gölü, II Van Gölü'dür.",
            "map_template": "turkiye_goller",
            "map_markers": json.dumps(VALID_MARKERS),
            "test_assignment": "auto",
            "is_published": "on",
        }

    def test_panel_save_generates_persistent_map_image(self):
        self.client.force_login(self.staff)
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            self._payload(),
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertEqual(question.map_template, "turkiye_goller")
        self.assertEqual(len(question.map_markers), 2)
        self.assertTrue(question.image.name.endswith(".png"))
        self.assertTrue(question.image.storage.exists(question.image.name))

    def test_panel_save_without_map_clears_leftover_markers(self):
        self.client.force_login(self.staff)
        payload = self._payload()
        payload["map_template"] = ""
        payload["map_markers"] = json.dumps(VALID_MARKERS)
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            payload,
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertEqual(question.map_template, "")
        self.assertEqual(question.map_markers, [])

    def test_invalid_map_payload_is_rejected(self):
        self.client.force_login(self.staff)
        payload = self._payload()
        payload["map_markers"] = json.dumps([dict(VALID_MARKERS[0], y=-1)])
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            payload,
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Question.objects.count(), 0)

    def test_panel_save_static_map_question(self):
        self.client.force_login(self.staff)
        payload = self._payload()
        payload["map_template"] = "turkiye_indirgenmis_sicaklik"
        payload["map_markers"] = "[]"
        payload["stem"] = "Haritaya göre en yüksek indirgenmiş sıcaklık nerededir?"
        response = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            payload,
        )
        self.assertEqual(response.status_code, 302)
        question = Question.objects.get()
        self.assertEqual(question.map_template, "turkiye_indirgenmis_sicaklik")
        self.assertEqual(question.map_markers, [])
        self.assertTrue(question.image.name.endswith(".png"))
        question.image.open("rb")
        try:
            data = question.image.read()
        finally:
            question.image.close()
        with Image.open(BytesIO(data)) as image:
            self.assertEqual(image.size, (592, 275))

    def test_serializer_keeps_existing_image_url_contract(self):
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_map_serializer",
            stem="Harita sorusu",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            map_template="turkiye_goller",
            map_markers=VALID_MARKERS,
        )
        question.image.save(
            "map_contract.png",
            ContentFile(render_map_question("turkiye_goller", VALID_MARKERS)),
        )
        request = RequestFactory().get("/api/v1/pack/")
        data = QuestionSerializer(question, context={"request": request}).data
        self.assertTrue(data["imageUrl"].startswith("http://testserver/media/"))
        self.assertNotIn("map_markers", data)
