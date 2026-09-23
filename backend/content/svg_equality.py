"""Stem'deki |AB|=|CD| eşitliklerinden SVG kenar tick'lerini güvenilir şekilde üret."""

from __future__ import annotations

import math
import re

from .svg_sanitize import sanitize_figure_svg

# Türkçe dahil harf sınıfı (kenar / köşe etiketleri)
_LETTER = r"A-Za-zÇĞİÖŞÜçğıöşü"
_SEG_TOKEN = rf"[{_LETTER}]{{2,}}"
_SEG_PIPE = rf"\|({_SEG_TOKEN})\|"
_SEG_FINDALL = re.compile(_SEG_PIPE, re.UNICODE)
_EQUALITY_CHAIN = re.compile(
    rf"{_SEG_PIPE}(?:\s*=\s*{_SEG_PIPE})+",
    re.UNICODE,
)

_LINE_TAG = re.compile(r"<\s*line\b[^>]*?/?>", re.IGNORECASE)
_ATTR = re.compile(
    r"""\b(x1|y1|x2|y2|x|y)\s*=\s*["']?\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*["']?""",
    re.IGNORECASE,
)
_TEXT_BLOCK = re.compile(
    r"<\s*text\b([^>]*)>(.*?)<\s*/\s*text\s*>",
    re.IGNORECASE | re.DOTALL,
)
_TSPAN_BLOCK = re.compile(
    r"<\s*tspan\b([^>]*)>(.*?)<\s*/\s*tspan\s*>",
    re.IGNORECASE | re.DOTALL,
)
_TAG_STRIP = re.compile(r"<[^>]+>")
_EQUALITY_BLOCK = re.compile(
    r"<!--\s*equality-ticks\s*-->.*?<!--\s*/equality-ticks\s*-->",
    re.IGNORECASE | re.DOTALL,
)

_TICK_LEN = 9.0
_TICK_SPACING = 3.5


def _norm_letter(ch: str) -> str:
    """Köşe harfini karşılaştırma için normalize et (Türkçe İ/ı → I)."""
    if ch in ("ı", "İ", "i", "I"):
        return "I"
    return ch.upper()


def _norm_seg(token: str) -> str:
    """Kenar yazımını büyük harfe çevir; çizim için verilen sırayı koru."""
    return "".join(_norm_letter(c) for c in token)


def _undirected_key(seg: str) -> frozenset[str]:
    s = _norm_seg(seg)
    if len(s) < 2:
        return frozenset()
    # İki uç harf (uzun etiketlerde ilk/son harf)
    return frozenset((s[0], s[-1]))


class _UnionFind:
    def __init__(self) -> None:
        self.parent: dict[frozenset[str], frozenset[str]] = {}

    def add(self, key: frozenset[str]) -> None:
        if key and key not in self.parent:
            self.parent[key] = key

    def find(self, key: frozenset[str]) -> frozenset[str]:
        self.add(key)
        while self.parent[key] != key:
            self.parent[key] = self.parent[self.parent[key]]
            key = self.parent[key]
        return key

    def union(self, a: frozenset[str], b: frozenset[str]) -> None:
        if not a or not b:
            return
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[rb] = ra


def extract_equal_segment_groups(stem: str) -> list[list[str]]:
    """Parse |AB|=|CD|, $|XY|=|ZW|$, |AB|=|CD|=|EF| into congruence groups (union-find).

    Segment tokens: 2+ consecutive letters (A-ZĞÜŞİÖÇ…). Normalize reverse AB==BA
    as the same undirected edge for grouping keys but keep first spelling for drawing.
    """
    text = stem or ""
    if not text:
        return []

    uf = _UnionFind()
    spelling: dict[frozenset[str], str] = {}
    order: list[frozenset[str]] = []

    def _register(raw: str) -> frozenset[str]:
        seg = _norm_seg(raw)
        key = _undirected_key(seg)
        if not key:
            return frozenset()
        if key not in spelling:
            spelling[key] = seg
            order.append(key)
        uf.add(key)
        return key

    for match in _EQUALITY_CHAIN.finditer(text):
        # Tekrarlayan capture grupları yalnızca son eşleşmeyi tutar; span içinden bul.
        segs = [_norm_seg(g) for g in _SEG_FINDALL.findall(match.group(0))]
        keys = [_register(s) for s in segs]
        keys = [k for k in keys if k]
        for i in range(len(keys) - 1):
            uf.union(keys[i], keys[i + 1])

    if not spelling:
        return []

    buckets: dict[frozenset[str], list[str]] = {}
    root_order: list[frozenset[str]] = []
    for key in order:
        root = uf.find(key)
        if root not in buckets:
            buckets[root] = []
            root_order.append(root)
        label = spelling[key]
        if label not in buckets[root]:
            buckets[root].append(label)

    return [buckets[r] for r in root_order if len(buckets[r]) >= 2]


def _attrs(blob: str) -> dict[str, float]:
    out: dict[str, float] = {}
    for m in _ATTR.finditer(blob or ""):
        out[m.group(1).lower()] = float(m.group(2))
    return out


def _plain_label(inner: str) -> str:
    text = _TAG_STRIP.sub("", inner or "")
    return re.sub(r"\s+", "", text).strip()


def parse_svg_point_labels(svg: str) -> dict[str, tuple[float, float]]:
    """Map single-letter (or short) <text x=".." y="..">L</text> labels to coordinates.

    Also support x/y on parent <text> with tspan. Prefer last occurrence if duplicates.
    """
    points: dict[str, tuple[float, float]] = {}
    for tm in _TEXT_BLOCK.finditer(svg or ""):
        parent_attrs = _attrs(tm.group(1))
        inner = tm.group(2)
        tspans = list(_TSPAN_BLOCK.finditer(inner))
        if tspans:
            for ts in tspans:
                t_attrs = {**parent_attrs, **_attrs(ts.group(1))}
                label = _plain_label(ts.group(2))
                if not label or len(label) > 3:
                    continue
                if "x" in t_attrs and "y" in t_attrs:
                    points[_norm_letter(label[0]) if len(label) == 1 else _norm_seg(label)] = (
                        t_attrs["x"],
                        t_attrs["y"],
                    )
            continue
        label = _plain_label(inner)
        if not label or len(label) > 3:
            continue
        if "x" not in parent_attrs or "y" not in parent_attrs:
            continue
        key = _norm_letter(label[0]) if len(label) == 1 else _norm_seg(label)
        # Tek harf köşe; kısa ölçü metinlerini (32°) at
        if len(label) == 1 and label[0].isalpha():
            points[key] = (parent_attrs["x"], parent_attrs["y"])
        elif len(label) <= 3 and label.isalpha():
            points[key] = (parent_attrs["x"], parent_attrs["y"])
    return points


def strip_short_hatch_lines(svg: str, max_len: float = 18.0) -> str:
    """Remove <line> elements whose Euclidean length <= max_len (equality ticks).

    Do not remove longer figure edges. Keep circles/polygons/text/paths.
    """
    if not svg:
        return ""

    def _repl(m: re.Match[str]) -> str:
        a = _attrs(m.group(0))
        if not all(k in a for k in ("x1", "y1", "x2", "y2")):
            return m.group(0)
        length = math.hypot(a["x2"] - a["x1"], a["y2"] - a["y1"])
        if length <= max_len:
            return ""
        return m.group(0)

    return _LINE_TAG.sub(_repl, svg)


def _segment_endpoints(
    seg: str, points: dict[str, tuple[float, float]]
) -> tuple[tuple[float, float], tuple[float, float]] | None:
    s = _norm_seg(seg)
    if len(s) < 2:
        return None
    a, b = s[0], s[-1]
    if a not in points or b not in points:
        return None
    return points[a], points[b]


def _tick_lines_for_segment(
    p1: tuple[float, float],
    p2: tuple[float, float],
    count: int,
    *,
    tick_len: float = _TICK_LEN,
    spacing: float = _TICK_SPACING,
) -> list[str]:
    if count < 1:
        return []
    mx = (p1[0] + p2[0]) / 2.0
    my = (p1[1] + p2[1]) / 2.0
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = math.hypot(dx, dy) or 1.0
    ux, uy = dx / length, dy / length
    px, py = -uy, ux  # perpendicular
    half = ((count - 1) * spacing) / 2.0
    out: list[str] = []
    for i in range(count):
        along = -half + i * spacing
        cx = mx + ux * along
        cy = my + uy * along
        x1 = cx + px * (tick_len / 2.0)
        y1 = cy + py * (tick_len / 2.0)
        x2 = cx - px * (tick_len / 2.0)
        y2 = cy - py * (tick_len / 2.0)
        out.append(
            f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
            f'stroke="black" stroke-width="1.5" fill="none"/>'
        )
    return out


def build_equality_tick_markup(
    groups: list[list[str]],
    points: dict[str, tuple[float, float]],
) -> str:
    """For group i, draw (i+1) perpendicular tick marks at each segment midpoint.

    Segment 'AB' needs points A and B. Skip missing points.
    """
    lines: list[str] = []
    for gi, group in enumerate(groups):
        n_ticks = gi + 1
        for seg in group:
            ends = _segment_endpoints(seg, points)
            if not ends:
                continue
            lines.extend(_tick_lines_for_segment(ends[0], ends[1], n_ticks))
    if not lines:
        return ""
    body = "\n".join(f"  {ln}" for ln in lines)
    return f"<!-- equality-ticks -->\n{body}\n<!-- /equality-ticks -->\n"


def repair_equality_ticks(svg: str, stem: str) -> str:
    """If no groups or <2 labels, return svg unchanged.

    Else: strip short hatches, inject build_equality_tick_markup before </svg>.
    Re-sanitize via sanitize_figure_svg at end.
    """
    code = (svg or "").strip()
    if not code:
        return svg or ""
    groups = extract_equal_segment_groups(stem or "")
    points = parse_svg_point_labels(code)
    if not groups or len(points) < 2:
        return code

    cleaned = _EQUALITY_BLOCK.sub("", code)
    cleaned = strip_short_hatch_lines(cleaned)
    markup = build_equality_tick_markup(groups, points)
    if markup:
        lower = cleaned.lower()
        idx = lower.rfind("</svg>")
        if idx >= 0:
            cleaned = cleaned[:idx] + markup + cleaned[idx:]
    sanitized = sanitize_figure_svg(cleaned)
    return sanitized if sanitized else cleaned
