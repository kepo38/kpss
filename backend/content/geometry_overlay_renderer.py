"""Geometri sorularında Gemini annotasyon JSON → orijinal görsel üzerine sayı yazımı."""

from __future__ import annotations

import io
import logging
from typing import Any

from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger(__name__)

COLOR_ALIASES: dict[str, tuple[int, int, int]] = {
    "mavi": (37, 99, 235),
    "blue": (37, 99, 235),
    "kirmizi": (220, 38, 38),
    "kırmızı": (220, 38, 38),
    "red": (220, 38, 38),
}

DEFAULT_COLORS = {
    "known": (37, 99, 235),
    "result": (220, 38, 38),
}


def _clamp1000(value: Any) -> float | None:
    try:
        num = float(value)
    except (TypeError, ValueError):
        return None
    return max(0.0, min(1000.0, num))


def normalize_geometry_annotations(raw: Any) -> list[dict[str, Any]]:
    """Gemini `geometri_annotasyonlari` listesini doğrula."""
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        text = str(
            item.get("metin")
            or item.get("text")
            or item.get("label")
            or item.get("value")
            or ""
        ).strip()
        if not text:
            continue
        bbox_raw = item.get("bbox") or item.get("kutu") or item.get("box")
        if not isinstance(bbox_raw, (list, tuple)) or len(bbox_raw) < 4:
            continue
        coords = [_clamp1000(bbox_raw[i]) for i in range(4)]
        if any(v is None for v in coords):
            continue
        ymin, xmin, ymax, xmax = coords  # type: ignore[misc]
        if ymax <= ymin or xmax <= xmin:
            continue
        color_key = str(item.get("renk") or item.get("color") or "").strip().lower()
        out.append(
            {
                "text": text,
                "bbox": (float(ymin), float(xmin), float(ymax), float(xmax)),
                "color_key": color_key,
            }
        )
    return out


def _resolve_color(color_key: str) -> tuple[int, int, int]:
    key = (color_key or "").strip().lower()
    if key in COLOR_ALIASES:
        return COLOR_ALIASES[key]
    if key in {"sonuc", "sonuç", "result", "hesaplanan", "bulunan"}:
        return DEFAULT_COLORS["result"]
    if key in {"bilinen", "verilen", "known", "given"}:
        return DEFAULT_COLORS["known"]
    return DEFAULT_COLORS["result"]


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "arialbd.ttf",
        "Arial Bold.ttf",
        "DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def render_geometry_annotations(
    image_bytes: bytes,
    annotations: list[dict[str, Any]],
    *,
    scale: float = 1.0,
) -> bytes | None:
    """Annotasyonları orijinal görselin üzerine çiz; PNG döndür."""
    normalized = (
        annotations
        if annotations and "bbox" in annotations[0]
        else normalize_geometry_annotations(annotations)
    )
    if not normalized:
        return None
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            base = img.convert("RGBA")
            draw = ImageDraw.Draw(base)
            width, height = base.size
            font_size = max(14, int(min(width, height) * 0.035 * scale))
            font = _load_font(font_size)
            stroke = max(1, font_size // 10)

            for item in normalized:
                text = str(item.get("text") or "").strip()
                if not text:
                    continue
                ymin, xmin, ymax, xmax = item["bbox"]
                cx = int(((xmin + xmax) / 2.0 / 1000.0) * width)
                cy = int(((ymin + ymax) / 2.0 / 1000.0) * height)
                fill = _resolve_color(str(item.get("color_key") or ""))

                bbox = draw.textbbox((0, 0), text, font=font)
                tw = bbox[2] - bbox[0]
                th = bbox[3] - bbox[1]
                x = cx - tw // 2
                y = cy - th // 2

                pad = max(2, stroke)
                draw.rectangle(
                    (x - pad, y - pad, x + tw + pad, y + th + pad),
                    fill=(255, 255, 255, 210),
                )
                draw.text(
                    (x, y),
                    text,
                    font=font,
                    fill=fill + (255,),
                    stroke_width=stroke,
                    stroke_fill=(255, 255, 255, 255),
                )

            out = io.BytesIO()
            base.convert("RGB").save(out, format="PNG", optimize=True)
            return out.getvalue()
    except Exception:
        logger.exception("geometry overlay render failed")
        return None
