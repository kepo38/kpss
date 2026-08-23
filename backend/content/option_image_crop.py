"""Görsel şık kırpma — Gemini bbox veya ızgara dilimleme + şeffaf PNG."""

from __future__ import annotations

import base64
import io
from typing import Any

from PIL import Image

OPTION_KEYS = ("A", "B", "C", "D", "E")
VISUAL_OPTION_PLACEHOLDER = "Görsel şık"


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def normalize_option_boxes(
    raw: Any,
) -> dict[str, tuple[float, float, float, float]]:
    """Harf → (x, y, w, h) normalize 0–1."""
    if not isinstance(raw, dict):
        return {}
    out: dict[str, tuple[float, float, float, float]] = {}
    for key in OPTION_KEYS:
        box = raw.get(key) or raw.get(key.lower())
        if not isinstance(box, (list, tuple)) or len(box) < 4:
            continue
        try:
            x, y, w, h = (
                _clamp01(box[0]),
                _clamp01(box[1]),
                _clamp01(box[2]),
                _clamp01(box[3]),
            )
        except (TypeError, ValueError):
            continue
        if w < 0.02 or h < 0.02:
            continue
        if x + w > 1.0:
            w = 1.0 - x
        if y + h > 1.0:
            h = 1.0 - y
        out[key] = (x, y, w, h)
    return out


def boxes_look_valid(boxes: dict[str, tuple[float, float, float, float]]) -> bool:
    if len(boxes) < 3:
        return False
    items = list(boxes.values())
    for i, (x1, y1, w1, h1) in enumerate(items):
        a1 = w1 * h1
        for x2, y2, w2, h2 in items[i + 1 :]:
            ix0 = max(x1, x2)
            iy0 = max(y1, y2)
            ix1 = min(x1 + w1, x2 + w2)
            iy1 = min(y1 + h1, y2 + h2)
            if ix1 <= ix0 or iy1 <= iy0:
                continue
            inter = (ix1 - ix0) * (iy1 - iy0)
            if a1 > 0 and inter / a1 > 0.55:
                return False
    return True


def _box_center(
    box: tuple[float, float, float, float],
) -> tuple[float, float]:
    x, y, w, h = box
    return (x + w / 2.0, y + h / 2.0)


def assign_boxes_reading_order(
    boxes: dict[str, tuple[float, float, float, float]],
) -> dict[str, tuple[float, float, float, float]]:
    """Gemini harf etiketine güvenme — kutuları satır satır (y, sonra x) sırala → A–E.

    Tipik ÖSYM görsel şık düzeni:
      A B C
      D E
    veya tek satır / tek sütun. Harf anahtarları karışmış olsa bile geometri doğruysa
    okuma sırası şıkları düzeltir.
    """
    if len(boxes) < 2:
        return dict(boxes)
    ordered = sorted(boxes.values(), key=lambda b: (_box_center(b)[1], _box_center(b)[0]))
    # Satır kümeleme: dikey merkez farkı eşik altındaysa aynı satır
    rows: list[list[tuple[float, float, float, float]]] = []
    row_ys: list[float] = []
    for box in ordered:
        cy = _box_center(box)[1]
        if not rows:
            rows.append([box])
            row_ys.append(cy)
            continue
        if abs(cy - row_ys[-1]) <= 0.085:
            rows[-1].append(box)
            # satır ortalama y'yi güncelle
            row_ys[-1] = sum(_box_center(b)[1] for b in rows[-1]) / len(rows[-1])
        else:
            rows.append([box])
            row_ys.append(cy)
    flat: list[tuple[float, float, float, float]] = []
    for row in rows:
        flat.extend(sorted(row, key=lambda b: _box_center(b)[0]))
    out: dict[str, tuple[float, float, float, float]] = {}
    for key, box in zip(OPTION_KEYS, flat, strict=False):
        out[key] = box
    return out


def equal_band_boxes(
    *,
    band_top: float = 0.55,
    band_bottom: float = 0.98,
    pad_x: float = 0.02,
) -> dict[str, tuple[float, float, float, float]]:
    """Alt bantta A–E eşit dilimler (tek satır yedek)."""
    height = max(0.08, band_bottom - band_top)
    usable = 1.0 - 2 * pad_x
    slot = usable / 5.0
    out: dict[str, tuple[float, float, float, float]] = {}
    for i, key in enumerate(OPTION_KEYS):
        x = pad_x + i * slot
        out[key] = (x, band_top, slot * 0.96, height)
    return out


def grid_option_boxes(
    *,
    band_top: float = 0.52,
    band_bottom: float = 0.97,
    pad_x: float = 0.04,
    gap: float = 0.02,
) -> dict[str, tuple[float, float, float, float]]:
    """Görsel şıklar için yaygın 3+2 ızgara (üst A B C, alt D E ortalı)."""
    height = max(0.1, band_bottom - band_top)
    row_h = (height - gap) / 2.0
    usable = 1.0 - 2 * pad_x
    top_slot = usable / 3.0
    out: dict[str, tuple[float, float, float, float]] = {}
    for i, key in enumerate(("A", "B", "C")):
        out[key] = (
            pad_x + i * top_slot + gap * 0.25,
            band_top,
            top_slot - gap * 0.5,
            row_h,
        )
    bottom_slot = usable / 2.0
    bottom_y = band_top + row_h + gap
    # D–E ortalı: iki slot, satır ortasında
    for i, key in enumerate(("D", "E")):
        out[key] = (
            pad_x + 0.5 * top_slot + i * bottom_slot + gap * 0.25,
            bottom_y,
            bottom_slot - gap * 0.5,
            row_h,
        )
    return out


def knock_out_paper_background(
    img: Image.Image,
    *,
    tolerance: int = 48,
) -> Image.Image:
    """Sayfa kağıdı / açık zemini alfa kanalına çevir (PNG şeffaflık)."""
    rgba = img.convert("RGBA")
    width, height = rgba.size
    if width < 2 or height < 2:
        return rgba
    px = rgba.load()
    assert px is not None
    # Köşe örnekleri — tipik kağıt rengi
    samples = [
        px[1, 1][:3],
        px[width - 2, 1][:3],
        px[1, height - 2][:3],
        px[width - 2, height - 2][:3],
        px[width // 2, 1][:3],
    ]
    br = sum(s[0] for s in samples) // len(samples)
    bg = sum(s[1] for s in samples) // len(samples)
    bb = sum(s[2] for s in samples) // len(samples)
    # Çok koyu köşe = görsel kenarı; o zaman açık kağıda yakın pikselleri hedefle
    if br + bg + bb < 480:
        br, bg, bb = 250, 250, 250

    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            near_paper = (
                abs(r - br) <= tolerance
                and abs(g - bg) <= tolerance
                and abs(b - bb) <= tolerance
            )
            # Açık gri / kirli beyaz kağıt (JPEG sıkıştırma)
            light_paper = lum >= 232 and max(r, g, b) - min(r, g, b) <= 28
            if near_paper or light_paper or (r >= 245 and g >= 245 and b >= 245):
                px[x, y] = (r, g, b, 0)
    return rgba


def _encode_option_png(region: Image.Image) -> bytes:
    transparent = knock_out_paper_background(region)
    buf = io.BytesIO()
    transparent.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def crop_option_images(
    image_bytes: bytes,
    boxes: dict[str, tuple[float, float, float, float]] | Any | None = None,
    *,
    padding: float = 0.01,
) -> dict[str, bytes]:
    """Sayfa görselinden A–E şeffaf PNG crop'ları üret."""
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    width, height = img.size
    normalized = normalize_option_boxes(boxes) if boxes else {}
    if boxes_look_valid(normalized):
        # Harf etiketleri Gemini'de karışabiliyor — konuma göre yeniden etiketle
        use_boxes = assign_boxes_reading_order(normalized)
    else:
        # Tek satır 5'li nadiren doğru; görsel şıklarda 3+2 daha yaygın
        use_boxes = grid_option_boxes()
    crops: dict[str, bytes] = {}
    for key in OPTION_KEYS:
        box = use_boxes.get(key)
        if not box:
            continue
        x, y, w, h = box
        left = int(max(0, (x - padding) * width))
        top = int(max(0, (y - padding) * height))
        right = int(min(width, (x + w + padding) * width))
        bottom = int(min(height, (y + h + padding) * height))
        if right - left < 8 or bottom - top < 8:
            continue
        region = img.crop((left, top, right, bottom))
        crops[key] = _encode_option_png(region)
    return crops


def crops_to_data_urls(crops: dict[str, bytes]) -> dict[str, str]:
    return {
        key: "data:image/png;base64," + base64.b64encode(data).decode("ascii")
        for key, data in crops.items()
        if data
    }


def data_url_to_bytes(data_url: str) -> bytes | None:
    raw = (data_url or "").strip()
    if not raw.startswith("data:") or "," not in raw:
        return None
    try:
        _header, b64 = raw.split(",", 1)
        return base64.b64decode(b64)
    except Exception:  # noqa: BLE001
        return None
