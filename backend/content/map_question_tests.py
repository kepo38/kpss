import json
import tempfile
from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.core.files.base import ContentFile
from django.test import RequestFactory, SimpleTestCase, TestCase
from PIL import Image, ImageDraw

from .map_question_renderer import (
    _draw_map_marker,
    _font,
    _roman_label_size,
    render_map_question,
    validate_map_markers,
)
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


class RomanKerningTests(SimpleTestCase):
    def test_ii_and_iii_are_tighter_than_full_i_advances(self):
        font = _font(80)
        img = Image.new("RGB", (240, 80), "white")
        draw = ImageDraw.Draw(img)
        i_box = draw.textbbox((0, 0), "I", font=font, stroke_width=4)
        i_w = i_box[2] - i_box[0]
        w_ii, _ = _roman_label_size(draw, "II", font, 4)
        w_iii, _ = _roman_label_size(draw, "III", font, 4)
        self.assertLess(w_ii, i_w * 2 * 0.9)
        self.assertLess(w_iii, i_w * 3 * 0.9)


class MapMarkerValidationTests(SimpleTestCase):
    def test_normalizes_valid_markers(self):
        result = validate_map_markers("turkiye_goller", VALID_MARKERS)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["x"], 42.5)
        self.assertEqual(result[1]["labelSide"], "left")

    def test_normalizes_circle_and_ellipse_rotation(self):
        markers = [
            dict(VALID_MARKERS[0], shape="circle", width=3.2, height=4.8, rotation=90),
            dict(VALID_MARKERS[1], shape="ellipse", rotation=90),
        ]
        result = validate_map_markers("turkiye_goller", markers)
        self.assertEqual(result[0]["shape"], "circle")
        self.assertEqual(result[0]["width"], 3.2)
        self.assertEqual(result[0]["height"], 3.2)
        self.assertEqual(result[0]["rotation"], 0)
        self.assertEqual(result[1]["shape"], "ellipse")
        self.assertEqual(result[1]["rotation"], 90)

    def test_normalizes_line_thickness_and_ends(self):
        result = validate_map_markers(
            "turkiye_goller",
            [
                {
                    "shape": "line",
                    "x": 40,
                    "y": 12,
                    "x2": 55,
                    "y2": 88,
                    "width": 1.6,
                    "color": "#ef4444",
                }
            ],
        )
        self.assertEqual(result[0]["shape"], "line")
        self.assertEqual(result[0]["x2"], 55)
        self.assertEqual(result[0]["width"], 1.6)
        self.assertFalse(result[0]["showLabel"])

    def test_line_can_hide_city_labels(self):
        result = validate_map_markers(
            "turkiye_goller",
            [
                {
                    "shape": "line",
                    "x": 40,
                    "y": 12,
                    "x2": 55,
                    "y2": 88,
                    "width": 1.6,
                    "showLabel": False,
                    "label": "Ankara",
                }
            ],
        )
        self.assertFalse(result[0]["showLabel"])
        self.assertEqual(result[0]["label"], "Ankara")

    def test_line_autofills_city_name_on_adana(self):
        result = validate_map_markers(
            "turkiye_goller",
            [
                {
                    "shape": "line",
                    "x": 53.0,
                    "y": 81.5,
                    "x2": 51.0,
                    "y2": 83.0,
                    "width": 1.2,
                    "showLabel": True,
                }
            ],
        )
        self.assertIn("Adana", result[0]["label"])
        self.assertEqual(result[0]["startLabel"], "Adana")
        self.assertEqual(result[0]["endLabel"], "Adana")

    def test_line_keeps_explicit_start_and_end_labels(self):
        result = validate_map_markers(
            "turkiye_goller",
            [
                {
                    "shape": "line",
                    "x": 40,
                    "y": 40,
                    "x2": 60,
                    "y2": 60,
                    "width": 0.5,
                    "showLabel": True,
                    "startLabel": "Sivas",
                    "endLabel": "İzmir",
                }
            ],
        )
        self.assertEqual(result[0]["startLabel"], "Sivas")
        self.assertEqual(result[0]["endLabel"], "İzmir")
        self.assertEqual(result[0]["label"], "Sivas · İzmir")

    def test_normalizes_city_label_marker(self):
        result = validate_map_markers(
            "turkiye_goller",
            [
                {
                    "shape": "city-label",
                    "x": 53.0,
                    "y": 81.5,
                    "label": "Adana",
                }
            ],
        )
        self.assertEqual(result[0]["shape"], "city-label")
        self.assertEqual(result[0]["label"], "Adana")
        self.assertTrue(result[0]["showLabel"])

    def test_city_label_changes_render(self):
        hidden = {
            "shape": "city-label",
            "x": 53.0,
            "y": 81.5,
            "label": "Adana",
            "showLabel": False,
        }
        shown = dict(hidden, showLabel=True)
        self.assertNotEqual(
            render_map_question("turkiye_goller", [hidden]),
            render_map_question("turkiye_goller", [shown]),
        )

    def test_rejects_line_thickness_out_of_range(self):
        with self.assertRaises(ValidationError):
            validate_map_markers(
                "turkiye_goller",
                [{"shape": "line", "x": 10, "y": 10, "x2": 20, "y2": 20, "width": 9}],
            )

    def test_rejects_invalid_shape(self):
        invalid = [dict(VALID_MARKERS[0], shape="square")]
        with self.assertRaises(ValidationError):
            validate_map_markers("turkiye_goller", invalid)

    def test_rejects_out_of_bounds_coordinate(self):
        invalid = [dict(VALID_MARKERS[0], x=101)]
        with self.assertRaises(ValidationError):
            validate_map_markers("turkiye_goller", invalid)

    def test_ignores_markers_without_template(self):
        result = validate_map_markers("", VALID_MARKERS)
        self.assertEqual(result, [])
        self.assertEqual(validate_map_markers("", "[]"), [])

    def test_normalizes_province_fill(self):
        result = validate_map_markers(
            "turkiye_goller",
            [{"shape": "fill", "province": "tr-01"}],
        )
        self.assertEqual(result[0]["shape"], "fill")
        self.assertEqual(result[0]["province"], "tr-01")
        self.assertEqual(result[0]["color"], "#111827")

    def test_rejects_unknown_province_fill(self):
        with self.assertRaises(ValidationError):
            validate_map_markers(
                "turkiye_goller",
                [{"shape": "fill", "province": "tr-99"}],
            )

    def test_allows_fill_without_pin_markers(self):
        result = validate_map_markers(
            "turkiye_goller",
            [{"shape": "fill", "province": "tr-06", "color": "#111827"}],
        )
        self.assertEqual(len(result), 1)

    def test_normalizes_brush_stroke(self):
        result = validate_map_markers(
            "turkiye_goller",
            [
                {
                    "shape": "brush",
                    "color": "#ef4444",
                    "width": 2.5,
                    "points": [[40, 50], [42, 51], [44, 52]],
                }
            ],
        )
        self.assertEqual(result[0]["shape"], "brush")
        self.assertEqual(result[0]["width"], 2.5)
        self.assertEqual(len(result[0]["points"]), 3)

    def test_rejects_empty_brush_points(self):
        with self.assertRaises(ValidationError):
            validate_map_markers(
                "turkiye_goller",
                [{"shape": "brush", "color": "#ef4444", "width": 2, "points": []}],
            )

    def test_brush_does_not_consume_pin_slots(self):
        brushes = [
            {
                "shape": "brush",
                "color": "#111827",
                "width": 2,
                "points": [[10 + i, 50], [11 + i, 51]],
            }
            for i in range(5)
        ]
        result = validate_map_markers(
            "turkiye_goller",
            brushes + VALID_MARKERS,
        )
        self.assertEqual(sum(1 for m in result if m["shape"] == "brush"), 5)
        self.assertEqual(sum(1 for m in result if m["shape"] != "brush"), 2)


class MapRendererTests(SimpleTestCase):
    def test_renders_province_fill(self):
        blank = render_map_question("turkiye_goller", VALID_MARKERS)
        painted = render_map_question(
            "turkiye_goller",
            [{"shape": "fill", "province": "tr-01", "color": "#111827"}] + VALID_MARKERS,
        )
        self.assertNotEqual(blank, painted)
        raw = render_map_question("turkiye_goller", VALID_MARKERS)
        with Image.open(BytesIO(raw)) as image:
            self.assertEqual(image.format, "PNG")
            self.assertEqual(image.size, (1600, 700))
            self.assertEqual(image.convert("RGBA").getpixel((2, 2))[3], 255)
            paper = image.convert("RGBA").getpixel((2, 2))
            self.assertGreater(paper[0], 230)
            self.assertGreater(paper[1], 230)
            self.assertGreater(paper[2], 230)

    def test_renders_brush_stroke(self):
        blank = render_map_question("turkiye_goller", VALID_MARKERS)
        brushed = render_map_question(
            "turkiye_goller",
            [
                {
                    "shape": "brush",
                    "color": "#ef4444",
                    "width": 3.0,
                    "points": [[35, 48], [40, 50], [45, 52], [50, 50]],
                }
            ]
            + VALID_MARKERS,
        )
        self.assertNotEqual(blank, brushed)

    def test_brush_clipped_off_land_does_not_paint_corner_paper(self):
        """Sea/corner stroke should not tint paper corner after flatten."""
        raw = render_map_question(
            "turkiye_goller",
            [
                {
                    "shape": "brush",
                    "color": "#ff0000",
                    "width": 5.0,
                    "points": [[1, 1], [2, 2], [3, 1], [2, 3]],
                }
            ]
            + VALID_MARKERS,
        )
        with Image.open(BytesIO(raw)) as image:
            pixel = image.convert("RGBA").getpixel((2, 2))
            self.assertGreater(pixel[0], 200)
            self.assertGreater(pixel[1], 200)
            self.assertGreater(pixel[2], 200)

    def test_circle_is_round_not_map_aspect_ellipse(self):
        image = Image.new("RGBA", (1600, 700), (0, 0, 0, 0))
        box = _draw_map_marker(
            image,
            {
                "x": 50,
                "y": 50,
                "width": 5,
                "height": 5,
                "shape": "circle",
                "rotation": 0,
                "color": "#ef4444",
            },
            stroke=2,
        )
        self.assertAlmostEqual(box[2] - box[0], box[3] - box[1], delta=1)
        self.assertAlmostEqual(box[2] - box[0], 80, delta=1)

    def test_draws_line_between_endpoints(self):
        image = Image.new("RGBA", (1000, 500), (248, 250, 252, 255))
        box = _draw_map_marker(
            image,
            {
                "shape": "line",
                "x": 20,
                "y": 20,
                "x2": 80,
                "y2": 80,
                "width": 1.5,
                "color": "#ef4444",
            },
            stroke=2,
        )
        self.assertLess(box[0], box[2])
        self.assertLess(box[1], box[3])

    def test_city_labels_change_rendered_line(self):
        hidden = {
            "shape": "line",
            "x": 52.2,
            "y": 82.4,
            "x2": 52.4,
            "y2": 82.6,
            "width": 1.4,
            "color": "#ef4444",
            "showLabel": False,
        }
        shown = dict(hidden, showLabel=True, label="Adana")
        self.assertNotEqual(
            render_map_question("turkiye_goller", [hidden]),
            render_map_question("turkiye_goller", [shown]),
        )

    def test_ellipse_can_hide_roman_label(self):
        hidden = dict(VALID_MARKERS[0], shape="ellipse", showLabel=False)
        shown = dict(VALID_MARKERS[0], shape="ellipse", showLabel=True)
        result = validate_map_markers("turkiye_goller", [hidden])
        self.assertFalse(result[0]["showLabel"])
        self.assertNotEqual(
            render_map_question("turkiye_goller", [hidden]),
            render_map_question("turkiye_goller", [shown]),
        )

    def test_renders_rotated_ellipse_and_circle(self):
        markers = [
            dict(VALID_MARKERS[0], rotation=90, shape="ellipse"),
            dict(VALID_MARKERS[1], shape="circle", width=2.6, height=2.6),
        ]
        raw = render_map_question("turkiye_goller", markers)
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
