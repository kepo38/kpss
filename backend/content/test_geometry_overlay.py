from django.test import SimpleTestCase

from content.geometry_overlay_renderer import (
    normalize_geometry_annotations,
    render_geometry_annotations,
)
from content.ocr_gemini import _payload_geometry_annotations


class GeometryOverlayRendererTests(SimpleTestCase):
    def test_normalize_annotations_bbox_1000(self):
        raw = [
            {
                "metin": "x = 4/3",
                "bbox": [300, 680, 340, 760],
                "renk": "kirmizi",
            },
            {
                "text": "10",
                "bbox": [420, 510, 460, 570],
                "color": "mavi",
            },
        ]
        out = normalize_geometry_annotations(raw)
        self.assertEqual(len(out), 2)
        self.assertEqual(out[0]["text"], "x = 4/3")
        self.assertEqual(out[0]["color_key"], "kirmizi")
        self.assertEqual(out[1]["text"], "10")

    def test_payload_geometry_annotations_from_gemini_json(self):
        data = {
            "geometri_annotasyonlari": [
                {"metin": "R=4", "bbox": [100, 200, 140, 260], "renk": "mavi"}
            ]
        }
        out = _payload_geometry_annotations(data)
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0]["text"], "R=4")

    def test_render_returns_png_bytes(self):
        from PIL import Image
        import io

        img = Image.new("RGB", (400, 300), color=(255, 255, 255))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        annotations = normalize_geometry_annotations(
            [{"metin": "5", "bbox": [150, 150, 190, 210], "renk": "mavi"}]
        )
        rendered = render_geometry_annotations(buf.getvalue(), annotations)
        self.assertIsNotNone(rendered)
        assert rendered is not None
        self.assertTrue(rendered.startswith(b"\x89PNG"))
