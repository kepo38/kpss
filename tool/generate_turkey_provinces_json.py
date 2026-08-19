"""Project Turkey provinces to percent coords matching turkiye_goller maps."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_turkey_lakes_map import (  # noqa: E402
    HEIGHT,
    MAPS_DIR,
    PROVINCES_URL,
    SCALE,
    WIDTH,
    _fetch,
    _polygons,
    _project,
    _turkey_provinces,
)

OUTPUT = MAPS_DIR / "turkiye_iller.json"
MIN_STEP = 0.12


def _slug(properties: dict) -> str:
    iso = (properties.get("iso_3166_2") or "").strip().lower().replace(" ", "")
    if iso.startswith("tr-") and len(iso) >= 5:
        return iso
    raw = (
        properties.get("name_en")
        or properties.get("name")
        or properties.get("name_tr")
        or "il"
    )
    table = str.maketrans("çğıöşüÇĞİÖŞÜâîû", "cgiosuCGIOSUaiu")
    slug = "".join(ch.lower() if ch.isalnum() else "-" for ch in str(raw).translate(table))
    return "-".join(part for part in slug.split("-") if part) or "il"


def _simplify(points: list[list[float]]) -> list[list[float]]:
    if len(points) < 4:
        return points
    kept = [points[0]]
    for point in points[1:-1]:
        prev = kept[-1]
        if abs(point[0] - prev[0]) + abs(point[1] - prev[1]) >= MIN_STEP:
            kept.append(point)
    last = points[-1]
    if kept[0] != last:
        kept.append(last)
    if len(kept) < 4:
        return points
    return kept


def _percent(point: list[float]) -> list[float]:
    x, y = _project(point)
    return [
        round(x / (WIDTH * SCALE) * 100, 2),
        round(y / (HEIGHT * SCALE) * 100, 2),
    ]


def main() -> None:
    provinces = _turkey_provinces(_fetch(PROVINCES_URL)["features"])
    payload = []
    for feature in provinces:
        properties = feature["properties"]
        rings = []
        for polygon in _polygons(feature["geometry"]):
            if not polygon:
                continue
            ring = _simplify([_percent(pt) for pt in polygon[0]])
            if len(ring) >= 4:
                rings.append(ring)
        if not rings:
            continue
        payload.append(
            {
                "id": _slug(properties),
                "name": (properties.get("name_tr") or properties.get("name") or "").strip(),
                "polygons": rings,
            }
        )
    payload.sort(key=lambda item: item["name"])
    MAPS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps({"provinces": payload}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"Wrote {OUTPUT} ({len(payload)} provinces, {OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
