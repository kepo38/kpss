"""Stem'deki |AB|=|CD| eşitliklerinden SVG kenar tick'lerini güvenilir şekilde üret."""

from __future__ import annotations

import math
import re

from .svg_sanitize import sanitize_figure_svg

# Türkçe dahil harf sınıfı (kenar / köşe etiketleri)
_LETTER = r"A-Za-zÇĞİÖŞÜçğıöşü"
_SEG_TOKEN = rf"[{_LETTER}]{{2,}}"
_SEG_PIPE = rf"\|({_SEG_TOKEN})\|"
# 2|MC| / 4|KB| oran yazımı — eşitlik DEĞİL (negatif lookbehind: rakam yok)
_SEG_PIPE_BARE = rf"(?<![0-9])\|({_SEG_TOKEN})\|"
_SEG_FINDALL = re.compile(_SEG_PIPE, re.UNICODE)
_EQUALITY_CHAIN = re.compile(
    rf"{_SEG_PIPE_BARE}(?:\s*=\s*{_SEG_PIPE_BARE})+",
    re.UNICODE,
)

_LINE_TAG = re.compile(r"<\s*line\b[^>]*?/?>", re.IGNORECASE)
_CIRCLE_TAG = re.compile(r"<\s*circle\b[^>]*?/?>", re.IGNORECASE)
_POLYGON_TAG = re.compile(r"<\s*polygon\b([^>]*)/?>", re.IGNORECASE)
_ATTR = re.compile(
    r"""\b(x1|y1|x2|y2|x|y|cx|cy|r)\s*=\s*["']?\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*["']?""",
    re.IGNORECASE,
)
_POINTS_ATTR = re.compile(
    r"""\bpoints\s*=\s*["']([^"']+)["']""",
    re.IGNORECASE,
)
_POINT_PAIR = re.compile(
    r"([+-]?(?:\d+\.?\d*|\.\d+))\s*[, ]\s*([+-]?(?:\d+\.?\d*|\.\d+))"
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
_DEFS_BLOCK = re.compile(
    r"<\s*defs\b[^>]*>.*?<\s*/\s*defs\s*>",
    re.IGNORECASE | re.DOTALL,
)
_EQUALITY_BLOCK = re.compile(
    r"<!--\s*equality-ticks\s*-->.*?<!--\s*/equality-ticks\s*-->",
    re.IGNORECASE | re.DOTALL,
)
_PATH_TAG = re.compile(r"<\s*path\b[^>]*?/?>", re.IGNORECASE)
_PATH_D = re.compile(
    r"""\bd\s*=\s*["']([^"']+)["']""",
    re.IGNORECASE,
)
_RIGHT_ANGLE_AUTH = re.compile(
    r"(?:\\\\perp|\\perp|⊥|90\s*\\?circ|90\s*°|dik\s*aç[ıi]|diklik)",
    re.IGNORECASE,
)

_TICK_LEN = 9.0
_TICK_SPACING = 3.5
# Etiket <text> köşeden dışarı ofsetli; tick için geometrik köşeye snap.
_SNAP_MAX_DIST = 48.0
_MIN_EDGE_LEN = 24.0  # kısa hatch / marker kenarlarını anchor sayma
_RIGHT_ANGLE_MAX_LEG = 28.0  # OCR'ın uydurduğu küçük dik açı karesi

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
    Returns raw text positions (not snapped); use parse_svg_vertex_points for ticks.
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


def collect_svg_geometry_anchors(svg: str) -> list[tuple[float, float]]:
    """Köşe / uç nokta adayları: circle merkezleri, polygon vertices, uzun çizgi uçları.

    <defs> içindeki marker polygon'ları atlanır. Kısa hatch kenarları anchor değildir.
    """
    code = _DEFS_BLOCK.sub("", svg or "")
    anchors: list[tuple[float, float]] = []
    seen: set[tuple[float, float]] = set()

    def _add(x: float, y: float) -> None:
        key = (round(x, 2), round(y, 2))
        if key in seen:
            return
        seen.add(key)
        anchors.append((x, y))

    for m in _CIRCLE_TAG.finditer(code):
        a = _attrs(m.group(0))
        if "cx" in a and "cy" in a:
            _add(a["cx"], a["cy"])

    for m in _POLYGON_TAG.finditer(code):
        pm = _POINTS_ATTR.search(m.group(1) or "")
        if not pm:
            continue
        pairs = _POINT_PAIR.findall(pm.group(1))
        # Marker / dekoratif küçük polygon'ları ele
        if len(pairs) < 3:
            continue
        xs = [float(p[0]) for p in pairs]
        ys = [float(p[1]) for p in pairs]
        span = max(max(xs) - min(xs), max(ys) - min(ys))
        if span < 20.0:
            continue
        for x, y in pairs:
            _add(float(x), float(y))

    for m in _LINE_TAG.finditer(code):
        a = _attrs(m.group(0))
        if not all(k in a for k in ("x1", "y1", "x2", "y2")):
            continue
        length = math.hypot(a["x2"] - a["x1"], a["y2"] - a["y1"])
        if length < _MIN_EDGE_LEN:
            continue
        _add(a["x1"], a["y1"])
        _add(a["x2"], a["y2"])

    return anchors


def snap_labels_to_geometry(
    labels: dict[str, tuple[float, float]],
    anchors: list[tuple[float, float]],
    *,
    max_dist: float = _SNAP_MAX_DIST,
) -> dict[str, tuple[float, float]]:
    """Her etiketi en yakın geometrik köşeye taşı; eşleşme yoksa text konumunu koru.

    Aynı anchora birden fazla etiket düşerse, en yakın etiket kazanır; diğerleri
    sıradaki adaya veya text konumuna düşer.
    """
    if not labels:
        return {}
    if not anchors:
        return dict(labels)

    # (label, anchor_idx, dist) adayları, mesafe artan
    candidates: list[tuple[str, int, float]] = []
    for lab, (lx, ly) in labels.items():
        for i, (ax, ay) in enumerate(anchors):
            d = math.hypot(lx - ax, ly - ay)
            if d <= max_dist:
                candidates.append((lab, i, d))
    candidates.sort(key=lambda t: t[2])

    used_labels: set[str] = set()
    used_anchors: set[int] = set()
    snapped: dict[str, tuple[float, float]] = {}
    for lab, ai, _d in candidates:
        if lab in used_labels or ai in used_anchors:
            continue
        used_labels.add(lab)
        used_anchors.add(ai)
        snapped[lab] = anchors[ai]

    for lab, pos in labels.items():
        if lab not in snapped:
            snapped[lab] = pos
    return snapped


def parse_svg_vertex_points(svg: str) -> dict[str, tuple[float, float]]:
    """Tick yerleştirme için köşe koordinatları: text etiket + geometri snap."""
    labels = parse_svg_point_labels(svg)
    anchors = collect_svg_geometry_anchors(svg)
    return snap_labels_to_geometry(labels, anchors)


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


def stem_authorizes_right_angle_marks(stem: str) -> bool:
    """Stem'de ⊥ / 90° / dik açı yoksa OCR dik açı karesi uydurma."""
    return bool(_RIGHT_ANGLE_AUTH.search(stem or ""))


def _parse_simple_right_angle_path(d: str) -> bool:
    """İki kısa dik bacaklı M-L-L path → OCR dik açı işareti mi?"""
    if not d:
        return False
    tokens = re.findall(
        r"[MmLl]|[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?",
        d.replace(",", " "),
    )
    if len(tokens) < 7:
        return False
    pts: list[tuple[float, float]] = []
    i = 0
    cmd = "M"
    while i < len(tokens):
        t = tokens[i]
        if t in "MmLl":
            cmd = t.upper()
            i += 1
            continue
        if i + 1 >= len(tokens):
            break
        try:
            x = float(t)
            y = float(tokens[i + 1])
        except ValueError:
            break
        pts.append((x, y))
        i += 2
        if cmd == "M" and len(pts) == 1:
            cmd = "L"
    if len(pts) != 3:
        return False
    p0, p1, p2 = pts
    v1 = (p1[0] - p0[0], p1[1] - p0[1])
    v2 = (p2[0] - p1[0], p2[1] - p1[1])
    len1 = math.hypot(*v1)
    len2 = math.hypot(*v2)
    if len1 < 4 or len2 < 4:
        return False
    if len1 > _RIGHT_ANGLE_MAX_LEG or len2 > _RIGHT_ANGLE_MAX_LEG:
        return False
    if abs(v1[0] * v2[0] + v1[1] * v2[1]) > 0.15 * len1 * len2:
        return False
    return True


def strip_unauthorized_right_angle_marks(svg: str, stem: str) -> str:
    """Stem diklik söylemiyorsa küçük sağ-açı path'lerini sil (kare uydurması)."""
    if not svg or stem_authorizes_right_angle_marks(stem):
        return svg or ""

    def _repl(m: re.Match[str]) -> str:
        tag = m.group(0)
        dm = _PATH_D.search(tag)
        if not dm:
            return tag
        if _parse_simple_right_angle_path(dm.group(1)):
            return ""
        return tag

    return _PATH_TAG.sub(_repl, svg)


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


def _point_on_segment(
    p: tuple[float, float],
    a: tuple[float, float],
    b: tuple[float, float],
    *,
    tol: float = 3.0,
) -> bool:
    """p, ab doğru parçası üzerinde mi (kolinear + uçlar arasında)?"""
    ax, ay = a
    bx, by = b
    px, py = p
    abx, aby = bx - ax, by - ay
    apx, apy = px - ax, py - ay
    ab_len = math.hypot(abx, aby)
    if ab_len < 1e-6:
        return math.hypot(apx, apy) <= tol
    # dik mesafe
    cross = abs(abx * apy - aby * apx) / ab_len
    if cross > tol:
        return False
    # izdüşüm parametresi
    t = (apx * abx + apy * aby) / (ab_len * ab_len)
    return -0.02 <= t <= 1.02


def _segment_properly_contains(
    outer: tuple[tuple[float, float], tuple[float, float]],
    inner: tuple[tuple[float, float], tuple[float, float]],
    *,
    tol: float = 3.0,
) -> bool:
    """inner'ın her iki ucu outer üzerinde ve inner, outer'dan belirgin şekilde kısa mı?"""
    o1, o2 = outer
    i1, i2 = inner
    if not (_point_on_segment(i1, o1, o2, tol=tol) and _point_on_segment(i2, o1, o2, tol=tol)):
        return False
    outer_len = math.hypot(o2[0] - o1[0], o2[1] - o1[1])
    inner_len = math.hypot(i2[0] - i1[0], i2[1] - i1[1])
    # Aynı kenar (ters yazım) veya neredeyse eşit uzunluk → içerme sayma
    if inner_len >= outer_len - tol:
        return False
    return inner_len < outer_len * 0.92


def filter_tick_groups_for_nesting(
    groups: list[list[str]],
    points: dict[str, tuple[float, float]],
) -> list[list[str]]:
    """İç içe kenarlarda çift tick yığınını önle.

    Örnek: |AB|=|BC|=|BE| ve |BD|=|BF| (D∈AB) → AB üzerinde hem AB hem BD
    tick'i biner. Bu durumda içerme yapan *üst grubun tamamı* bastırılır;
    görsel olarak ÖSYM gibi yalnızca iç eşitlik (BD=BF) işaretlenir.
    """
    if len(groups) < 2:
        return groups

    resolved: list[tuple[list[str], list[tuple[tuple[float, float], tuple[float, float]]]]] = []
    for group in groups:
        segs: list[str] = []
        ends_list: list[tuple[tuple[float, float], tuple[float, float]]] = []
        for seg in group:
            ends = _segment_endpoints(seg, points)
            if not ends:
                continue
            segs.append(seg)
            ends_list.append(ends)
        if len(segs) >= 2:
            resolved.append((segs, ends_list))

    if len(resolved) < 2:
        return [segs for segs, _ in resolved] if resolved else groups

    suppress: set[int] = set()
    for i, (_segs_i, ends_i) in enumerate(resolved):
        for j, (_segs_j, ends_j) in enumerate(resolved):
            if i == j:
                continue
            # i grubundaki bir kenar, j grubundaki bir kenarı içeriyorsa i'yi bastır
            for outer in ends_i:
                for inner in ends_j:
                    if _segment_properly_contains(outer, inner):
                        suppress.add(i)
                        break
                if i in suppress:
                    break

    kept = [segs for idx, (segs, _) in enumerate(resolved) if idx not in suppress]
    return kept if kept else [segs for segs, _ in resolved]


def _segment_has_intermediate_vertex(
    ends: tuple[tuple[float, float], tuple[float, float]],
    points: dict[str, tuple[float, float]],
    *,
    end_labels: frozenset[str],
    tol: float = 3.0,
) -> bool:
    """Kenar uçları arasında başka bir etiketli köşe var mı?

    Örnek: |KL| ve A-K-B-L doğrusal → B, K ile L arasında.
    Ortaya tick konursa görsel olarak AK=BL gibi durur (yanlış).
    """
    a, b = ends
    ab_len = math.hypot(b[0] - a[0], b[1] - a[1])
    if ab_len < 1e-6:
        return False
    for lab, p in points.items():
        if lab in end_labels:
            continue
        if not _point_on_segment(p, a, b, tol=tol):
            continue
        # Uçlara yapışık etiket sayma (ofset/snap gürültüsü)
        if math.hypot(p[0] - a[0], p[1] - a[1]) <= tol * 2:
            continue
        if math.hypot(p[0] - b[0], p[1] - b[1]) <= tol * 2:
            continue
        # Strictly between: t in (ε, 1-ε)
        ax, ay = a
        bx, by = b
        t = ((p[0] - ax) * (bx - ax) + (p[1] - ay) * (by - ay)) / (ab_len * ab_len)
        if 0.08 < t < 0.92:
            return True
    return False


def filter_tick_groups_skip_composite(
    groups: list[list[str]],
    points: dict[str, tuple[float, float]],
) -> list[list[str]]:
    """Bileşik kenarlı eşitlik gruplarını tick'ten çıkar.

    |AK|=|KL| (B ∈ KL) → KL ortasına tick, AK ile birlikte AK=BL illüzyonu yaratır.
    Bu gruplar metinde kalsın; kenar tick'i basılmasın.
    """
    kept: list[list[str]] = []
    for group in groups:
        composite = False
        atomic_segs: list[str] = []
        for seg in group:
            ends = _segment_endpoints(seg, points)
            if not ends:
                continue
            s = _norm_seg(seg)
            ends_lab = frozenset((s[0], s[-1]))
            if _segment_has_intermediate_vertex(ends, points, end_labels=ends_lab):
                composite = True
                break
            atomic_segs.append(seg)
        if composite:
            continue
        # Eksik uçlu kenarlar atılır; en az bir çizilebilir kenar kalsın
        # (eski davranış: CD yoksa yalnızca AB tick).
        if atomic_segs:
            kept.append(atomic_segs)
    return kept


def build_equality_tick_markup(
    groups: list[list[str]],
    points: dict[str, tuple[float, float]],
) -> str:
    """For group i, draw (i+1) perpendicular tick marks at each segment midpoint.

    Segment 'AB' needs points A and B. Skip missing points.
    Nested collinear groups are filtered first (see filter_tick_groups_for_nesting).
    Composite segments (intermediate vertex) drop the whole group — avoids
    |AK|=|KL| looking like |AK|=|BL| when B lies on KL.
    """
    groups = filter_tick_groups_for_nesting(groups, points)
    groups = filter_tick_groups_skip_composite(groups, points)
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
    """Stem'e göre tick'leri yenile; OCR'ın uydurduğu tick/dik açıları temizle.

    - Kısa hatch <line> her zaman silinir (yanlış AK=BL, CM=MB vb.).
    - Stem'de ⊥/90° yoksa küçük dik açı path'leri silinir (kare uydurması).
    - Yalnızca |XY|=|ZW| gruplarından tick enjekte edilir.
    - 4|KB|=2|MC|=|MB| gibi oranlar eşitlik grubu DEĞİLDİR.
    """
    code = (svg or "").strip()
    if not code:
        return svg or ""
    stem_text = stem or ""
    groups = extract_equal_segment_groups(stem_text)
    points = parse_svg_vertex_points(code)

    cleaned = _EQUALITY_BLOCK.sub("", code)
    cleaned = strip_short_hatch_lines(cleaned)
    cleaned = strip_unauthorized_right_angle_marks(cleaned, stem_text)

    if groups and len(points) >= 2:
        markup = build_equality_tick_markup(groups, points)
        if markup:
            lower = cleaned.lower()
            idx = lower.rfind("</svg>")
            if idx >= 0:
                cleaned = cleaned[:idx] + markup + cleaned[idx:]

    sanitized = sanitize_figure_svg(cleaned)
    return sanitized if sanitized else cleaned
