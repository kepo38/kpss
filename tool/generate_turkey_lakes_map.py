"""Generate the public-domain Turkey outline used by map questions.

Source data: Natural Earth 1:10m (public domain).
Only Turkey's outline, Lake Tuz and Lake Van are rendered.
Editor map also draws province borders and Turkish province names.
"""
from __future__ import annotations

import json
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


COUNTRIES_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_10m_admin_0_countries.geojson"
)
LAKES_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_10m_lakes.geojson"
)
PROVINCES_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_10m_admin_1_states_provinces.geojson"
)
MAPS_DIR = (
    Path(__file__).resolve().parents[1]
    / "backend"
    / "static"
    / "content"
    / "maps"
)
OUTPUT = MAPS_DIR / "turkiye_goller.png"
OUTPUT_EDITOR = MAPS_DIR / "turkiye_goller_editor.png"

WIDTH = 1600
HEIGHT = 700
SCALE = 2
BOUNDS = (25.4, 35.5, 45.0, 42.5)


def _fetch(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def _project(point: list[float]) -> tuple[int, int]:
    west, south, east, north = BOUNDS
    lon, lat = point[:2]
    x = (lon - west) / (east - west) * WIDTH * SCALE
    y = (north - lat) / (north - south) * HEIGHT * SCALE
    return round(x), round(y)


def _polygons(geometry: dict) -> list[list[list[list[float]]]]:
    kind = geometry["type"]
    coordinates = geometry["coordinates"]
    if kind == "Polygon":
        return [coordinates]
    if kind == "MultiPolygon":
        return coordinates
    raise ValueError(f"Unsupported geometry: {kind}")


def _draw_feature(
    draw: ImageDraw.ImageDraw,
    geometry: dict,
    *,
    fill: str | None,
    outline: str,
    width: int,
) -> None:
    for polygon in _polygons(geometry):
        if not polygon:
            continue
        outer = [_project(point) for point in polygon[0]]
        if fill is None:
            draw.line(outer + [outer[0]], fill=outline, width=width)
        else:
            draw.polygon(outer, fill=fill, outline=outline, width=width)
        for hole in polygon[1:]:
            hole_points = [_project(point) for point in hole]
            if fill is None:
                draw.line(hole_points + [hole_points[0]], fill=outline, width=width)
            else:
                draw.polygon(
                    hole_points,
                    fill="#ffffff",
                    outline=outline,
                    width=max(1, width // 2),
                )


def _turkey_provinces(features: list[dict]) -> list[dict]:
    provinces = [
        feature
        for feature in features
        if feature["properties"].get("admin") == "Turkey"
        or feature["properties"].get("iso_a2") == "TR"
    ]
    if len(provinces) < 70:
        raise RuntimeError("Turkey province boundaries were not found.")
    return provinces


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path(__file__).resolve().parent / "fonts" / "DejaVuSans.ttf",
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("C:/Windows/Fonts/segoeui.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _province_label(properties: dict) -> str:
    label = (properties.get("name_tr") or properties.get("name") or "").strip()
    return label


def _province_label_point(properties: dict) -> tuple[int, int] | None:
    lon = properties.get("longitude")
    lat = properties.get("latitude")
    if lon is None or lat is None:
        return None
    return _project([float(lon), float(lat)])


def _draw_province_labels(
    draw: ImageDraw.ImageDraw,
    provinces: list[dict],
    *,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
) -> None:
    for province in provinces:
        properties = province["properties"]
        label = _province_label(properties)
        point = _province_label_point(properties)
        if not label or point is None:
            continue
        x, y = point
        text_box = draw.textbbox((0, 0), label, font=font)
        text_w = text_box[2] - text_box[0]
        text_h = text_box[3] - text_box[1]
        left = x - text_w // 2
        top = y - text_h // 2
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            draw.text((left + dx, top + dy), label, fill="#ffffff", font=font)
        draw.text((left, top), label, fill="#334155", font=font)


def _render_base(
    *,
    include_province_borders: bool,
    include_province_labels: bool = False,
) -> Image.Image:
    countries = _fetch(COUNTRIES_URL)["features"]
    lakes = _fetch(LAKES_URL)["features"]
    turkey = next(
        feature
        for feature in countries
        if feature["properties"].get("ADMIN") == "Turkey"
    )
    selected_lakes = [
        feature
        for feature in lakes
        if feature["properties"].get("name") in {"Lake Tuz", "Lake Van"}
    ]
    if len(selected_lakes) != 2:
        raise RuntimeError("Lake Tuz and Lake Van were not both found.")

    image = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), "#ffffff")
    draw = ImageDraw.Draw(image)
    _draw_feature(
        draw,
        turkey["geometry"],
        fill="#e5e7eb",
        outline="#111827",
        width=7,
    )
    if include_province_borders:
        provinces = _turkey_provinces(_fetch(PROVINCES_URL)["features"])
        for province in provinces:
            _draw_feature(
                draw,
                province["geometry"],
                fill=None,
                outline="#94a3b8",
                width=2,
            )
        if include_province_labels:
            _draw_province_labels(
                draw,
                provinces,
                font=_load_font(22),
            )
    for lake in selected_lakes:
        _draw_feature(
            draw,
            lake["geometry"],
            fill="#6ec8e5",
            outline="#075985",
            width=4,
        )

    return image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)


def main() -> None:
    MAPS_DIR.mkdir(parents=True, exist_ok=True)
    clean = _render_base(include_province_borders=False)
    clean.save(OUTPUT, format="PNG", optimize=True)
    print(f"Generated {OUTPUT} ({WIDTH}x{HEIGHT})")

    editor = _render_base(
        include_province_borders=True,
        include_province_labels=True,
    )
    editor.save(OUTPUT_EDITOR, format="PNG", optimize=True)
    print(f"Generated {OUTPUT_EDITOR} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
