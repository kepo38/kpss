# -*- coding: utf-8 -*-
"""Shapebox / ÖSYM square-triangle-inside operators."""
from pathlib import Path

from django.test import SimpleTestCase

from content.rich_text_common import (
    normalize_latex,
    rewrite_symbolic_shape_operators,
)
from content.ocr import _likely_geometry_question

_MATH_RENDER = (
    Path(__file__).resolve().parents[1] / "static" / "panel" / "math-render.js"
)


class SymbolicShapeOperatorTests(SimpleTestCase):
    def test_rewrite_square_triangle_prefix_to_shapebox(self):
        src = r"$\square AB$ ve $\triangle AB$ → $\square 73 + \triangle 37$"
        out = rewrite_symbolic_shape_operators(src)
        self.assertIn(r"\shapebox{square}{AB}", out)
        self.assertIn(r"\shapebox{triangle}{AB}", out)
        self.assertIn(r"\shapebox{square}{73}", out)
        self.assertIn(r"\shapebox{triangle}{37}", out)
        self.assertNotIn(r"\square AB", out)
        self.assertNotIn(r"\triangle 37", out)

    def test_rewrite_unicode_boxes(self):
        out = rewrite_symbolic_shape_operators("□73 + △37")
        self.assertEqual(out, r"\shapebox{square}{73} + \shapebox{triangle}{37}")

    def test_rewrite_leaves_bare_and_compound_commands(self):
        self.assertEqual(rewrite_symbolic_shape_operators(r"\square"), r"\square")
        self.assertEqual(rewrite_symbolic_shape_operators(r"\triangleq"), r"\triangleq")
        self.assertEqual(rewrite_symbolic_shape_operators(r"\triangledown"), r"\triangledown")
        self.assertEqual(rewrite_symbolic_shape_operators(r"\blacksquare"), r"\blacksquare")

    def test_normalize_latex_applies_rewrite(self):
        out = normalize_latex(r"$\square 73 + \triangle 37$")
        self.assertIn(r"\shapebox{square}{73}", out)
        self.assertIn(r"\shapebox{triangle}{37}", out)

    def test_shapebox_not_geometry(self):
        stem = (
            r"AB iki basamaklı bir doğal sayı olmak üzere "
            r"$\shapebox{square}{AB}$ ve $\shapebox{triangle}{AB}$ ifadeleri "
            r"biçiminde tanımlanmaktadır. "
            r"$\shapebox{square}{73} + \shapebox{triangle}{37}$ ifadesinin değeri kaçtır?"
        )
        opts = {"A": "9", "B": "10", "C": "11", "D": "12", "E": "13"}
        self.assertFalse(_likely_geometry_question(stem, opts, stem))

    def test_panel_triangle_svg_has_intrinsic_size(self):
        """SVG without width/height attrs defaults to ~300×150 — must be explicit."""
        src = _MATH_RENDER.read_text(encoding="utf-8")
        self.assertIn("function shapeHtml", src)
        self.assertIn('width="32"', src)
        self.assertIn('height="28"', src)
        self.assertIn("max-width:2.2em", src)
        # Label must be drawn inside the SVG (not a sibling that can wrap away).
        self.assertIn("<text x=", src)
        self.assertIn('font-size="19"', src)
        # Compact inline scale (~1.7–1.85em), not full-bleed.
        self.assertIn("width:1.75em", src)
        self.assertIn("height:1.52em", src)

    def test_panel_triangle_label_vertically_centered(self):
        """Label ink center near △ visual/centroid band — not alphabetic baseline on the base."""
        src = _MATH_RENDER.read_text(encoding="utf-8")
        self.assertIn('dominant-baseline="central"', src)
        self.assertIn('y="21.2"', src)
        # Old base-pinned baseline must not return.
        self.assertNotIn('y="28.2"', src)
