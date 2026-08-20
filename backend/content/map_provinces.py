"""Turkey province polygons for map paint-bucket fills."""
from __future__ import annotations

import json
from functools import lru_cache
from typing import Any

from django.contrib.staticfiles import finders
from PIL import Image, ImageDraw

PROVINCES_ASSET = "content/maps/turkiye_iller.json"
MAX_FILLS = 81
DEFAULT_FILL_COLOR = "#111827"
MAX_LINE_CITY_LABELS = 4


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
