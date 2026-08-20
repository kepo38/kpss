"""Turkey province polygons for map paint-bucket fills and brush land masks."""
from __future__ import annotations

import json
from functools import lru_cache
from typing import Any

from django.contrib.staticfiles import finders
from PIL import Image, ImageChops, ImageDraw

PROVINCES_ASSET = "content/maps/turkiye_iller.json"
MAX_FILLS = 81
DEFAULT_FILL_COLOR = "#111827"
MAX_LINE_CITY_LABELS = 4
MAX_BRUSH_STROKES = 12
MAX_BRUSH_POINTS = 200
MIN_BRUSH_WIDTH = 0.8
MAX_BRUSH_WIDTH = 6.0


def _point_in_ring(x: float, y: float, ring: list) -> bool:
    inside = False
    j = len(ring) - 1
    for i, point in enumerate(ring):
        xi, yi = point[0], point[1]
        xj, yj = ring[j][0], ring[j][1]
        if yi != yj and (yi > y) != (yj > y) and x < ((xj - xi) * (y - yi)) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def province_at(x: float, y: float) -> dict[str, Any] | None:
    for province in load_provinces():
        for ring in province.get("polygons") or []:
            if len(ring) >= 3 and _point_in_ring(x, y, ring):
                return province
    return None


def line_city_names(x: float, y: float, x2: float, y2: float) -> list[str]:
    """Unique province names along a line, in order (capped)."""
    names: list[str] = []
    seen: set[str] = set()
    steps = 8
    for index in range(steps + 1):
        t = index / steps
        hit = province_at(x + (x2 - x) * t, y + (y2 - y) * t)
        if not hit:
            continue
        ident = str(hit.get("id") or "")
        name = str(hit.get("name") or "").strip()
        if not ident or ident in seen or not name:
            continue
        seen.add(ident)
        names.append(name)
    if len(names) > MAX_LINE_CITY_LABELS:
        return [names[0], names[-1]]
    return names


def line_endpoint_names(x: float, y: float, x2: float, y2: float) -> tuple[str, str]:
    start = province_at(x, y)
    end = province_at(x2, y2)
    start_name = str((start or {}).get("name") or "").strip()
    end_name = str((end or {}).get("name") or "").strip()
    return start_name, end_name


@lru_cache(maxsize=1)
def load_provinces() -> list[dict[str, Any]]:
    path = finders.find(PROVINCES_ASSET)
    if not path:
        return []
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return list(data.get("provinces") or [])


@lru_cache(maxsize=1)
def province_ids() -> frozenset[str]:
    return frozenset(item["id"] for item in load_provinces())


def draw_province_fills(image: Image.Image, fills: list[dict[str, Any]]) -> None:
    if not fills:
        return
    by_id = {item["id"]: item for item in load_provinces()}
    draw = ImageDraw.Draw(image)
    width, height = image.size
    for fill in fills:
        province = by_id.get(fill.get("province"))
        if not province:
            continue
        color = fill.get("color") or DEFAULT_FILL_COLOR
        for ring in province.get("polygons") or []:
            if len(ring) < 3:
                continue
            points = [(width * x / 100, height * y / 100) for x, y in ring]
            draw.polygon(points, fill=color)


def _hex_to_rgba(color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    raw = (color or DEFAULT_FILL_COLOR).lstrip("#")
    if len(raw) != 6:
        return (17, 24, 39, alpha)
    return (int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16), alpha)


@lru_cache(maxsize=4)
def build_land_mask(width: int, height: int) -> Image.Image:
    """Opaque land (255) from province polygons; sea/frame stay 0."""
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    for province in load_provinces():
        for ring in province.get("polygons") or []:
            if len(ring) < 3:
                continue
            points = [(width * x / 100.0, height * y / 100.0) for x, y in ring]
            draw.polygon(points, fill=255)
    return mask


def _densify_polyline(
    points: list[tuple[float, float]], step: float
) -> list[tuple[float, float]]:
    if not points:
        return []
    if len(points) == 1:
        return points[:]
    out: list[tuple[float, float]] = [points[0]]
    for i in range(1, len(points)):
        x0, y0 = out[-1]
        x1, y1 = points[i]
        dx = x1 - x0
        dy = y1 - y0
        dist = (dx * dx + dy * dy) ** 0.5
        if dist <= step:
            out.append((x1, y1))
            continue
        n = max(1, int(dist / step))
        for k in range(1, n + 1):
            t = k / n
            out.append((x0 + dx * t, y0 + dy * t))
    return out


def draw_brush_strokes(image: Image.Image, strokes: list[dict[str, Any]]) -> None:
    """Paint freehand strokes clipped to land (province union)."""
    if not strokes:
        return
    if image.mode != "RGBA":
        raise ValueError("draw_brush_strokes expects an RGBA image")
    width, height = image.size
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for stroke in strokes:
        pts_raw = stroke.get("points") or []
        if not pts_raw:
            continue
        color = _hex_to_rgba(str(stroke.get("color") or DEFAULT_FILL_COLOR))
        brush_w = float(stroke.get("width") or MIN_BRUSH_WIDTH)
        width_px = max(2, int(round(width * brush_w / 100.0)))
        radius = width_px / 2.0
        points = [
            (width * float(p[0]) / 100.0, height * float(p[1]) / 100.0)
            for p in pts_raw
            if isinstance(p, (list, tuple)) and len(p) >= 2
        ]
        if not points:
            continue
        stamped = _densify_polyline(points, step=max(1.0, width_px * 0.32))
        for x, y in stamped:
            draw.ellipse(
                (x - radius, y - radius, x + radius, y + radius),
                fill=color,
            )
    mask = build_land_mask(width, height)
    r, g, b, a = layer.split()
    a = ImageChops.multiply(a, mask)
    clipped = Image.merge("RGBA", (r, g, b, a))
    image.alpha_composite(clipped)
