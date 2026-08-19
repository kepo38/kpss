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
