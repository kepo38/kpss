"""svg_equality: stem eşitliklerinden tutarlı kenar tick üretimi."""

from __future__ import annotations

import math
import re

from django.test import SimpleTestCase

from content.svg_equality import (
    build_equality_tick_markup,
    collect_svg_geometry_anchors,
    extract_equal_segment_groups,
    filter_tick_groups_for_nesting,
    parse_svg_point_labels,
    parse_svg_vertex_points,
    repair_equality_ticks,
    strip_short_hatch_lines,
)

# q_62ae1bcb58 — Gemini'nin hatalı tick'li SVG'si (DB=DE yorumu, DE'de 2 tick)
BUGGY_SVG_Q62 = """<svg viewBox="0 0 400 250" xmlns="http://www.w3.org/2000/svg">
  <!-- Üçgenin köşeleri -->
  <polygon points="50,200 350,200 200,50" fill="none" stroke="black" stroke-width="2"/>

  <!-- D noktası (AB üzerinde) -->
  <circle cx="200" cy="200" r="2" fill="black"/>

  <!-- E noktası (BC üzerinde) -->
  <line x1="200" y1="200" x2="275" y2="125" stroke="black" stroke-width="2"/>
  <circle cx="275" cy="125" r="2" fill="black"/>

  <!-- CD çizgisi -->
  <line x1="200" y1="50" x2="200" y2="200" stroke="black" stroke-width="2"/>

  <!-- Köşe etiketleri -->
  <text x="40" y="220" font-size="16">A</text>
  <text x="355" y="220" font-size="16">B</text>
  <text x="195" y="40" font-size="16">C</text>
  <text x="195" y="220" font-size="16">D</text>
  <text x="285" y="120" font-size="16">E</text>

  <!-- Eşitlik işaretleri -->
  <!-- AD = DC -->
  <line x1="120" y1="195" x2="120" y2="205" stroke="black" stroke-width="1"/>
  <line x1="125" y1="195" x2="125" y2="205" stroke="black" stroke-width="1"/>

  <line x1="195" y1="120" x2="205" y2="120" stroke="black" stroke-width="1"/>
  <line x1="195" y1="125" x2="205" y2="125" stroke="black" stroke-width="1"/>

  <!-- DB = DE -->
  <line x1="290" y1="195" x2="290" y2="205" stroke="black" stroke-width="1"/>

  <line x1="235" y1="160" x2="242" y2="167" stroke="black" stroke-width="1"/>
  <line x1="238" y1="157" x2="245" y2="164" stroke="black" stroke-width="1"/>

  <!-- Açı 32 derece -->
  <path d="M 200 160 A 40 40 0 0 0 235 160 L 200 200 Z" fill="blue" fill-opacity="0.2" stroke="blue" stroke-width="1"/>
  <text x="150" y="150" font-size="14" fill="blue">32°</text>
  <path d="M 170 150 Q 190 140 200 160" fill="none" stroke="blue" stroke-width="1" marker-end="url(#arrowhead)"/>
  <defs>
    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="0" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="blue"/>
    </marker>
  </defs>
</svg>"""

STEM_Q62 = """ABC üçgen
$D \\in [AB]$, $E \\in [BC]$
$|AD| = |DC|$
$|DB| = |DE|$
$m(\\widehat{CDE}) = 32^\\circ$

Yukarıdaki verilere göre $m(\\widehat{ACB})$ kaç derecedir?"""

_LINE_RE = re.compile(
    r'<\s*line\b[^>]*?\bx1\s*=\s*["\']?([+-]?\d+(?:\.\d+)?)'
    r'[^>]*?\by1\s*=\s*["\']?([+-]?\d+(?:\.\d+)?)'
    r'[^>]*?\bx2\s*=\s*["\']?([+-]?\d+(?:\.\d+)?)'
    r'[^>]*?\by2\s*=\s*["\']?([+-]?\d+(?:\.\d+)?)[^>]*?/?>',
    re.IGNORECASE,
)


def _all_lines(svg: str) -> list[tuple[float, float, float, float]]:
    out: list[tuple[float, float, float, float]] = []
    for m in _LINE_RE.finditer(svg):
        out.append(tuple(float(m.group(i)) for i in range(1, 5)))  # type: ignore[arg-type]
    return out


def _midpoint(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
    return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)


def _short_lines_near(
    svg: str,
    mid: tuple[float, float],
    *,
    radius: float = 28.0,
    max_len: float = 18.0,
) -> int:
    count = 0
    for x1, y1, x2, y2 in _all_lines(svg):
        length = math.hypot(x2 - x1, y2 - y1)
        if length > max_len:
            continue
        cx, cy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
        if math.hypot(cx - mid[0], cy - mid[1]) <= radius:
            count += 1
    return count


class ExtractEqualSegmentGroupsTests(SimpleTestCase):
    def test_two_pairs(self):
        groups = extract_equal_segment_groups(STEM_Q62)
        self.assertEqual(len(groups), 2)
        flat = {frozenset(g) for g in groups}
        self.assertIn(frozenset({"AD", "DC"}), flat)
        self.assertIn(frozenset({"DB", "DE"}), flat)

    def test_chain_three(self):
        groups = extract_equal_segment_groups("|AB|=|CD|=|EF|")
        self.assertEqual(len(groups), 1)
        self.assertEqual(set(groups[0]), {"AB", "CD", "EF"})

    def test_reverse_same_edge(self):
        groups = extract_equal_segment_groups("|AB|=|BA| and |CD|=|AB|")
        # BA undirected-merge with AB; CD joins → one group
        self.assertEqual(len(groups), 1)
        # Drawing spellings: AB (first) and CD
        self.assertIn("AB", groups[0])
        self.assertIn("CD", groups[0])

    def test_latex_dollars(self):
        groups = extract_equal_segment_groups(r"$|XY|=|ZW|$")
        self.assertEqual(groups, [["XY", "ZW"]])


class ParseSvgPointLabelsTests(SimpleTestCase):
    def test_basic_labels(self):
        pts = parse_svg_point_labels(BUGGY_SVG_Q62)
        self.assertEqual(pts["A"], (40.0, 220.0))
        self.assertEqual(pts["D"], (195.0, 220.0))
        self.assertEqual(pts["E"], (285.0, 120.0))
        self.assertNotIn("32", pts)

    def test_tspan_inherits_parent_xy(self):
        svg = (
            '<svg><text x="10" y="20"><tspan>A</tspan></text>'
            '<text x="1" y="2"><tspan x="30" y="40">B</tspan></text></svg>'
        )
        pts = parse_svg_point_labels(svg)
        self.assertEqual(pts["A"], (10.0, 20.0))
        self.assertEqual(pts["B"], (30.0, 40.0))

    def test_last_duplicate_wins(self):
        svg = '<svg><text x="1" y="2">A</text><text x="9" y="8">A</text></svg>'
        self.assertEqual(parse_svg_point_labels(svg)["A"], (9.0, 8.0))


class SnapVertexPointsQ62Tests(SimpleTestCase):
    def test_anchors_from_polygon_and_circles(self):
        anchors = collect_svg_geometry_anchors(BUGGY_SVG_Q62)
        self.assertIn((50.0, 200.0), anchors)
        self.assertIn((350.0, 200.0), anchors)
        self.assertIn((200.0, 50.0), anchors)
        self.assertIn((200.0, 200.0), anchors)
        self.assertIn((275.0, 125.0), anchors)

    def test_vertex_snap_onto_geometry(self):
        pts = parse_svg_vertex_points(BUGGY_SVG_Q62)
        # Text ofsetli; tick için gerçek köşeler
        self.assertEqual(pts["A"], (50.0, 200.0))
        self.assertEqual(pts["B"], (350.0, 200.0))
        self.assertEqual(pts["C"], (200.0, 50.0))
        self.assertEqual(pts["D"], (200.0, 200.0))
        self.assertEqual(pts["E"], (275.0, 125.0))


class RepairEqualityTicksQ62Tests(SimpleTestCase):
    # Gerçek geometrik köşeler (text etiket ofseti değil)
    GEO = {
        "A": (50.0, 200.0),
        "B": (350.0, 200.0),
        "C": (200.0, 50.0),
        "D": (200.0, 200.0),
        "E": (275.0, 125.0),
    }

    def test_repair_matches_stem_groups(self):
        repaired = repair_equality_ticks(BUGGY_SVG_Q62, STEM_Q62)
        self.assertIn("equality-ticks", repaired)
        pts = self.GEO

        mid_db = _midpoint(pts["D"], pts["B"])
        mid_de = _midpoint(pts["D"], pts["E"])
        mid_ad = _midpoint(pts["A"], pts["D"])
        mid_dc = _midpoint(pts["D"], pts["C"])

        n_db = _short_lines_near(repaired, mid_db)
        n_de = _short_lines_near(repaired, mid_de)
        n_ad = _short_lines_near(repaired, mid_ad)
        n_dc = _short_lines_near(repaired, mid_dc)

        self.assertEqual(n_db, n_de, f"DB ticks={n_db} DE ticks={n_de}")
        self.assertEqual(n_ad, n_dc, f"AD ticks={n_ad} DC ticks={n_dc}")
        self.assertNotEqual(n_ad, n_db)
        self.assertGreaterEqual(n_ad, 1)
        self.assertGreaterEqual(n_db, 1)

    def test_no_roman_ticks_below_base(self):
        """Etiket ofseti yüzünden AB altına I/II düşmemeli."""
        repaired = repair_equality_ticks(BUGGY_SVG_Q62, STEM_Q62)
        # Eski hatalı midpoints: AD text mid ~ (117.5, 220), DB ~ (275, 220)
        self.assertEqual(_short_lines_near(repaired, (117.5, 220.0), radius=12), 0)
        self.assertEqual(_short_lines_near(repaired, (275.0, 220.0), radius=12), 0)
        # Tüm kısa tick merkezleri tabanın üstünde (y <= 205; AB y=200)
        for x1, y1, x2, y2 in _all_lines(repaired):
            length = math.hypot(x2 - x1, y2 - y1)
            if length > 18.0:
                continue
            cy = (y1 + y2) / 2.0
            self.assertLessEqual(cy, 205.0, f"tick below base: {(x1, y1, x2, y2)}")

    def test_strips_old_short_hatches(self):
        cleaned = strip_short_hatch_lines(BUGGY_SVG_Q62)
        # Figure kenarı DE (~106) ve CD (150) kalmalı
        self.assertIn('x1="200"', cleaned)
        self.assertIn('x2="275"', cleaned)
        # Kısa tick'ler gitmeli
        self.assertNotIn('x1="290"', cleaned)
        self.assertNotIn('x1="235"', cleaned)

    def test_build_markup_skips_missing_points(self):
        markup = build_equality_tick_markup([["AB", "CD"]], {"A": (0, 0), "B": (10, 0)})
        # CD missing → only AB ticks
        self.assertEqual(markup.count("<line"), 1)


class ProportionalNotEqualityTests(SimpleTestCase):
    def test_ratio_chain_is_not_equality_group(self):
        stem = "ABCD kare\n4|KB| = 2|MC| = |MB|\n|AK| = |KL|"
        groups = extract_equal_segment_groups(stem)
        self.assertEqual(len(groups), 1)
        self.assertEqual(set(groups[0]), {"AK", "KL"})

    def test_strips_wrong_ocr_ticks_and_right_angle(self):
        from content.svg_equality import (
            repair_equality_ticks,
            stem_authorizes_right_angle_marks,
        )

        self.assertFalse(stem_authorizes_right_angle_marks("ABCD kare\n|AK|=|KL|"))
        self.assertTrue(stem_authorizes_right_angle_marks(r"$CD \perp AB$"))

        buggy = """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <line x1="20" y1="180" x2="120" y2="180" stroke="black" stroke-width="2"/>
  <line x1="120" y1="180" x2="120" y2="40" stroke="black" stroke-width="2"/>
  <line x1="120" y1="180" x2="170" y2="180" stroke="black" stroke-width="2"/>
  <circle cx="70" cy="180" r="2" fill="black"/>
  <circle cx="120" cy="110" r="2" fill="black"/>
  <text x="18" y="195">A</text>
  <text x="68" y="195">K</text>
  <text x="122" y="195">B</text>
  <text x="168" y="195">L</text>
  <text x="128" y="112">M</text>
  <text x="125" y="35">C</text>
  <!-- wrong OCR: AK=BL double, CM=MB single, invented right angle -->
  <line x1="44" y1="175" x2="44" y2="185" stroke="black" stroke-width="1"/>
  <line x1="48" y1="175" x2="48" y2="185" stroke="black" stroke-width="1"/>
  <line x1="145" y1="175" x2="145" y2="185" stroke="black" stroke-width="1"/>
  <line x1="149" y1="175" x2="149" y2="185" stroke="black" stroke-width="1"/>
  <line x1="115" y1="70" x2="125" y2="70" stroke="black" stroke-width="1"/>
  <line x1="115" y1="140" x2="125" y2="140" stroke="black" stroke-width="1"/>
  <path d="M 120 180 L 120 164 L 136 164" fill="none" stroke="black" stroke-width="1.5"/>
</svg>"""
        stem = "ABCD kare\nA,K,B,L doğrusal\n|AK|=|KL|\n4|KB|=2|MC|=|MB|"
        repaired = repair_equality_ticks(buggy, stem)
        self.assertNotIn("L 120 164 L 136 164", repaired)
        # |AK|=|KL| ama B∈KL → bileşik kenar; tick YOK (AK=BL illüzyonu olmasın)
        mid_ak = (45.0, 180.0)
        mid_kl = (120.0, 180.0)
        mid_bl = (145.0, 180.0)
        self.assertEqual(_short_lines_near(repaired, mid_ak), 0)
        self.assertEqual(_short_lines_near(repaired, mid_kl), 0)
        self.assertEqual(_short_lines_near(repaired, mid_bl, radius=12), 0)

    def test_composite_kl_skips_ticks(self):
        from content.svg_equality import (
            build_equality_tick_markup,
            filter_tick_groups_skip_composite,
        )

        pts = {
            "A": (20.0, 180.0),
            "K": (70.0, 180.0),
            "B": (120.0, 180.0),
            "L": (170.0, 180.0),
        }
        groups = [["AK", "KL"]]
        filtered = filter_tick_groups_skip_composite(groups, pts)
        self.assertEqual(filtered, [])
        self.assertEqual(build_equality_tick_markup(groups, pts), "")


class NestedEqualityTickFilterTests(SimpleTestCase):
    """|AB|=|BC|=|BE| + |BD|=|BF| (D∈AB) → yalnızca BD/BF tek tick (ÖSYM)."""

    PTS = {
        "A": (28.0, 206.4),
        "D": (88.0, 206.4),
        "B": (268.0, 206.4),
        "C": (88.0, 47.6),
        "E": (428.6, 28.0),
        "F": (133.0, 87.3),
    }
    STEM = (
        "D∈[AB], F∈[BC]\n"
        "|AB|=|BC|=|BE|\n"
        "|BD|=|BF|\n"
        "|AD|=2\n"
        "|EF|=2√5"
    )

    def test_filter_suppresses_parent_group(self):
        groups = extract_equal_segment_groups(self.STEM)
        self.assertEqual(len(groups), 2)
        filtered = filter_tick_groups_for_nesting(groups, self.PTS)
        self.assertEqual(len(filtered), 1)
        self.assertEqual(set(filtered[0]), {"BD", "BF"})

    def test_repair_single_ticks_on_bd_bf_only(self):
        base = """<svg viewBox="0 0 464.6 242.4" xmlns="http://www.w3.org/2000/svg">
  <line x1="28.0" y1="206.4" x2="268.0" y2="206.4" stroke="black" stroke-width="2"/>
  <line x1="28.0" y1="206.4" x2="88.0" y2="47.6" stroke="black" stroke-width="2"/>
  <line x1="88.0" y1="47.6" x2="268.0" y2="206.4" stroke="black" stroke-width="2"/>
  <line x1="88.0" y1="47.6" x2="88.0" y2="206.4" stroke="black" stroke-width="2"/>
  <line x1="268.0" y1="206.4" x2="428.6" y2="28.0" stroke="black" stroke-width="2"/>
  <line x1="428.6" y1="28.0" x2="133.0" y2="87.3" stroke="black" stroke-width="2"/>
  <text x="16.0" y="226.4" font-size="16">A</text>
  <text x="83.0" y="226.4" font-size="16">D</text>
  <text x="276.0" y="226.4" font-size="16">B</text>
  <text x="72.0" y="51.6" font-size="16">C</text>
  <text x="434.6" y="32.0" font-size="16">E</text>
  <text x="119.0" y="81.3" font-size="16">F</text>
</svg>"""
        repaired = repair_equality_ticks(base, self.STEM)
        mid_bd = _midpoint(self.PTS["B"], self.PTS["D"])
        mid_bf = _midpoint(self.PTS["B"], self.PTS["F"])
        mid_ab = _midpoint(self.PTS["A"], self.PTS["B"])
        mid_bc = _midpoint(self.PTS["B"], self.PTS["C"])
        mid_be = _midpoint(self.PTS["B"], self.PTS["E"])
        self.assertEqual(_short_lines_near(repaired, mid_bd), 1)
        self.assertEqual(_short_lines_near(repaired, mid_bf), 1)
        # AB ortası BD tick'ine yakın olabilir; AB'nin sol yarısında tick olmamalı
        mid_ad_side = _midpoint(self.PTS["A"], self.PTS["D"])
        self.assertEqual(_short_lines_near(repaired, mid_ad_side, radius=20), 0)
        self.assertEqual(_short_lines_near(repaired, mid_bc, radius=20), 0)
        self.assertEqual(_short_lines_near(repaired, mid_be, radius=20), 0)
        # AB orta noktası BD midpoint'inden uzak (x≈148 vs x≈178)
        self.assertEqual(_short_lines_near(repaired, mid_ab, radius=14), 0)
