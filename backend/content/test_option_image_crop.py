"""Görsel şık kırpma birim testleri."""

from __future__ import annotations

import io
import unittest

from PIL import Image

from content.option_image_crop import (
    VISUAL_OPTION_PLACEHOLDER,
    assign_boxes_reading_order,
    boxes_look_valid,
    crop_option_images,
    crops_to_data_urls,
    equal_band_boxes,
    grid_option_boxes,
    knock_out_paper_background,
    normalize_option_boxes,
)
from content.ocr_gemini import _payload_option_boxes, _payload_options_visual


def _solid_jpeg(width: int = 400, height: int = 500) -> bytes:
    img = Image.new("RGB", (width, height), color=(240, 240, 240))
    # A–E bandına hafif renk şeritleri
    for i, color in enumerate(
        [(200, 80, 80), (80, 200, 80), (80, 80, 200), (200, 200, 80), (200, 80, 200)]
    ):
        x0 = int(i * width / 5)
        x1 = int((i + 1) * width / 5)
        for x in range(x0, x1):
            for y in range(int(height * 0.55), height - 4):
                img.putpixel((x, y), color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


class OptionImageCropTests(unittest.TestCase):
    def test_normalize_and_valid_boxes(self):
        boxes = normalize_option_boxes(
            {
                "A": [0.02, 0.55, 0.18, 0.35],
                "B": [0.22, 0.55, 0.18, 0.35],
                "C": [0.42, 0.55, 0.18, 0.35],
                "D": [0.62, 0.55, 0.18, 0.35],
                "E": [0.82, 0.55, 0.16, 0.35],
            }
        )
        self.assertEqual(len(boxes), 5)
        self.assertTrue(boxes_look_valid(boxes))

    def test_overlapping_boxes_invalid(self):
        boxes = normalize_option_boxes(
            {
                "A": [0.1, 0.5, 0.5, 0.4],
                "B": [0.15, 0.52, 0.5, 0.4],
                "C": [0.2, 0.54, 0.5, 0.4],
            }
        )
        self.assertFalse(boxes_look_valid(boxes))

    def test_assign_boxes_reading_order_swapped_labels(self):
        # Gemini harfleri ters: sağdaki kutuya A demiş
        raw = {
            "A": (0.70, 0.55, 0.18, 0.30),  # sağ → aslında E sırası (tek satır)
            "B": (0.52, 0.55, 0.18, 0.30),
            "C": (0.34, 0.55, 0.18, 0.30),
            "D": (0.16, 0.55, 0.18, 0.30),
            "E": (0.02, 0.55, 0.14, 0.30),  # sol → A
        }
        ordered = assign_boxes_reading_order(raw)
        self.assertEqual(ordered["A"], raw["E"])
        self.assertEqual(ordered["E"], raw["A"])

    def test_assign_boxes_reading_order_grid_3_2(self):
        # Karışık anahtarlar, 3+2 ızgara geometrisi
        raw = {
            "E": (0.08, 0.55, 0.25, 0.18),  # üst sol → A
            "D": (0.38, 0.55, 0.25, 0.18),  # üst orta → B
            "C": (0.68, 0.55, 0.25, 0.18),  # üst sağ → C
            "B": (0.20, 0.78, 0.28, 0.18),  # alt sol → D
            "A": (0.55, 0.78, 0.28, 0.18),  # alt sağ → E
        }
        ordered = assign_boxes_reading_order(raw)
        self.assertEqual(ordered["A"], raw["E"])
        self.assertEqual(ordered["B"], raw["D"])
        self.assertEqual(ordered["C"], raw["C"])
        self.assertEqual(ordered["D"], raw["B"])
        self.assertEqual(ordered["E"], raw["A"])

    def test_crop_with_gemini_boxes_png_transparent(self):
        image = _solid_jpeg()
        boxes = normalize_option_boxes(
            {
                "A": [0.02, 0.55, 0.18, 0.4],
                "B": [0.22, 0.55, 0.18, 0.4],
                "C": [0.42, 0.55, 0.18, 0.4],
                "D": [0.62, 0.55, 0.18, 0.4],
                "E": [0.82, 0.55, 0.16, 0.4],
            }
        )
        crops = crop_option_images(image, boxes)
        self.assertEqual(set(crops.keys()), {"A", "B", "C", "D", "E"})
        for data in crops.values():
            self.assertGreater(len(data), 200)
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            img = Image.open(io.BytesIO(data))
            self.assertEqual(img.mode, "RGBA")
        urls = crops_to_data_urls(crops)
        self.assertEqual(len(urls), 5)
        self.assertTrue(urls["A"].startswith("data:image/png;base64,"))

    def test_knock_out_makes_white_transparent(self):
        img = Image.new("RGB", (40, 40), color=(255, 255, 255))
        img.putpixel((20, 20), (30, 80, 200))
        out = knock_out_paper_background(img)
        self.assertEqual(out.mode, "RGBA")
        self.assertEqual(out.getpixel((1, 1))[3], 0)
        self.assertEqual(out.getpixel((20, 20))[3], 255)

    def test_crop_falls_back_to_grid(self):
        image = _solid_jpeg()
        crops = crop_option_images(image, {"A": [0.0, 0.0, 0.9, 0.9]})
        self.assertEqual(len(crops), 5)
        self.assertEqual(len(grid_option_boxes()), 5)
        self.assertEqual(len(equal_band_boxes()), 5)

    def test_payload_options_visual_and_boxes(self):
        self.assertTrue(
            _payload_options_visual({"gorisel_siklar": True})
        )
        self.assertFalse(
            _payload_options_visual({"gorisel_siklar": False})
        )
        boxes = _payload_option_boxes(
            {
                "sik_kutulari": {
                    "A": [0.1, 0.5, 0.15, 0.3],
                    "B": [0.3, 0.5, 0.15, 0.3],
                }
            }
        )
        self.assertIn("A", boxes)
        self.assertEqual(len(boxes["A"]), 4)
        self.assertEqual(VISUAL_OPTION_PLACEHOLDER, "Görsel şık")


if __name__ == "__main__":
    unittest.main()
