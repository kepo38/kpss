"""Validation and server-side rendering for coordinate map questions."""

from __future__ import annotations



import json
import math
import re
from collections import deque
from io import BytesIO
from pathlib import Path
from typing import Any



from django.contrib.staticfiles import finders

from django.core.exceptions import ValidationError

from PIL import Image, ImageDraw, ImageFont



from .map_catalog import get_map_entry, is_marker_template, is_static_template

from .map_provinces import (
    DEFAULT_FILL_COLOR,
    MAX_FILLS,
    draw_province_fills,
    line_endpoint_names,
    province_at,
    province_ids,
)





MAX_MARKERS = 12

DEFAULT_COLOR = "#ef4444"

ALLOWED_LABEL_SIDES = {"left", "right", "top", "bottom"}

ALLOWED_SHAPES = {"ellipse", "circle", "fill", "line", "city-label"}

HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")





def _number(value: Any, name: str, minimum: float, maximum: float) -> float:

    try:

        number = float(value)

    except (TypeError, ValueError) as exc:

        raise ValidationError(f"{name} sayısal olmalı.") from exc

    if not minimum <= number <= maximum:

        raise ValidationError(f"{name} {minimum:g}–{maximum:g} arasında olmalı.")

    return round(number, 2)





def validate_map_markers(
    template: str,
    markers: Any,
) -> list[dict[str, Any]]:
    """Return normalized marker data or raise ValidationError."""
    template = (template or "").strip()
    if not template:
        if isinstance(markers, str):
            try:
                markers = json.loads(markers or "[]")
            except json.JSONDecodeError:
                markers = []
        if markers in (None, []):
            return []
        return []

    entry = get_map_entry(template)
    if not entry:
        raise ValidationError("Desteklenmeyen harita şablonu.")
    if is_static_template(template):
        return []
    if isinstance(markers, str):
        try:
            markers = json.loads(markers or "[]")
        except json.JSONDecodeError as exc:
            raise ValidationError("Harita işaretleri geçerli JSON değil.") from exc
    if not isinstance(markers, list):
        raise ValidationError("Harita işaretleri liste olmalı.")
    if not markers:
        raise ValidationError("Harita sorusunda en az bir işaret veya boyalı il olmalı.")

    known_ids = province_ids()
    pin_count = 0
    fill_count = 0
    normalized: list[dict[str, Any]] = []
    for index, raw in enumerate(markers, start=1):
        if not isinstance(raw, dict):
            raise ValidationError(f"{index}. işaret geçersiz.")
        shape = str(raw.get("shape") or "ellipse").strip().lower()
        if shape not in ALLOWED_SHAPES:
            raise ValidationError(f"{index}. işaret şekli geçersiz.")
        color = str(
            raw.get("color") or (DEFAULT_FILL_COLOR if shape == "fill" else DEFAULT_COLOR)
        ).strip()
        if not HEX_COLOR.fullmatch(color):
            raise ValidationError(f"{index}. işaret rengi geçersiz.")
        if shape == "fill":
            fill_count += 1
            if fill_count > MAX_FILLS:
                raise ValidationError(f"En fazla {MAX_FILLS} il boyanabilir.")
            province = str(raw.get("province") or "").strip().lower()
            if province not in known_ids:
                raise ValidationError(f"{index}. boyalı il geçersiz.")
            normalized.append(
                {"shape": "fill", "province": province, "color": color.lower()}
            )
            continue
        pin_count += 1
        if pin_count > MAX_MARKERS:
            raise ValidationError(f"En fazla {MAX_MARKERS} işaret eklenebilir.")
        if shape == "line":
            x1 = _number(raw.get("x"), f"{index}. doğru X1", 0, 100)
            y1 = _number(raw.get("y"), f"{index}. doğru Y1", 0, 100)
            x2 = _number(raw.get("x2"), f"{index}. doğru X2", 0, 100)
            y2 = _number(raw.get("y2"), f"{index}. doğru Y2", 0, 100)
            if "showLabel" in raw:
                show_label = bool(raw.get("showLabel"))
            else:
                show_label = bool(
                    str(raw.get("label") or raw.get("startLabel") or raw.get("endLabel") or "").strip()
                )
            start_label = str(raw.get("startLabel") or "").strip()[:40]
            end_label = str(raw.get("endLabel") or "").strip()[:40]
            label = str(raw.get("label") or "").strip()[:80]
            auto_start, auto_end = line_endpoint_names(x1, y1, x2, y2)
            if not start_label:
                start_label = auto_start
            if not end_label:
                end_label = auto_end
            if not label:
                label = " · ".join(part for part in (start_label, end_label) if part)
            normalized.append(
                {
                    "shape": "line",
                    "x": x1,
                    "y": y1,
                    "x2": x2,
                    "y2": y2,
                    "width": _number(
                        raw.get("width", 0.5), f"{index}. doğru kalınlığı", 0.4, 4
                    ),
                    "height": 0,
                    "rotation": 0,
                    "color": color.lower(),
                    "labelSide": "right",
                    "showLabel": show_label,
                    "label": label,
                    "startLabel": start_label,
                    "endLabel": end_label,
                }
            )
            continue
        if shape == "city-label":
            pin_count += 1
            if pin_count > MAX_MARKERS:
                raise ValidationError(f"En fazla {MAX_MARKERS} işaret eklenebilir.")
            x = _number(raw.get("x"), f"{index}. il adı X", 0, 100)
            y = _number(raw.get("y"), f"{index}. il adı Y", 0, 100)
            if "showLabel" in raw:
                show_label = bool(raw.get("showLabel"))
            else:
                show_label = bool(str(raw.get("label") or "").strip())
            label = str(raw.get("label") or "").strip()[:40]
            if not label:
                hit = province_at(x, y)
                label = str((hit or {}).get("name") or "").strip()[:40]
            normalized.append(
                {
                    "shape": "city-label",
                    "x": x,
                    "y": y,
                    "width": 0,
                    "height": 0,
                    "rotation": 0,
                    "color": color.lower(),
                    "labelSide": "right",
                    "showLabel": show_label,
                    "label": label,
                }
            )
            continue
        label_side = str(raw.get("labelSide") or "right").strip()
        if label_side not in ALLOWED_LABEL_SIDES:
            raise ValidationError(f"{index}. etiket yönü geçersiz.")
        width = _number(
            raw.get("width", 2.6 if shape == "circle" else 4.5),
            f"{index}. işaret genişliği",
            1,
            15,
        )
        height = _number(
            raw.get("height", 2.6 if shape == "circle" else 3.5),
            f"{index}. işaret yüksekliği",
            1,
            15,
        )
        if shape == "circle":
            height = width
            rotation = 0
        else:
            rotation = int(
                _number(raw.get("rotation", 0), f"{index}. işaret dönüşü", 0, 179)
            )
        if "showLabel" in raw:
            show_label = bool(raw.get("showLabel"))
        else:
            show_label = True
        normalized.append(
            {
                "x": _number(raw.get("x"), f"{index}. işaret X", 0, 100),
                "y": _number(raw.get("y"), f"{index}. işaret Y", 0, 100),
                "width": width,
                "height": height,
                "rotation": rotation,
                "shape": shape,
                "color": color.lower(),
                "labelSide": label_side,
                "showLabel": show_label,
            }
        )
    return normalized


def _roman(number: int) -> str:

    values = (

        (10, "X"),

        (9, "IX"),

        (5, "V"),

        (4, "IV"),

        (1, "I"),

    )

    result = ""

    for value, symbol in values:

        while number >= value:

            result += symbol

            number -= value

    return result





def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
        Path("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"),
        Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
        Path("/System/Library/Fonts/Helvetica.ttc"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/timesbd.ttf"),
        Path("C:/Windows/Fonts/georgia.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _roman_glyph_advance(ch: str, glyph_width: int) -> int:
    """Georgia/serif I has wide side bearings — II/III looks gappy without this."""
    if ch == "I":
        return max(1, round(glyph_width * 0.78))
    return glyph_width


def _roman_label_size(
    draw: ImageDraw.ImageDraw,
    label: str,
    font: ImageFont.ImageFont,
    stroke_width: int,
) -> tuple[int, int]:
    width = 0
    height = 0
    for ch in label:
        box = draw.textbbox((0, 0), ch, font=font, stroke_width=stroke_width)
        width += _roman_glyph_advance(ch, box[2] - box[0])
        height = max(height, box[3] - box[1])
    return width, height


def _draw_roman_label(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    label: str,
    *,
    font: ImageFont.ImageFont,
    fill: str,
    stroke_width: int,
    stroke_fill: str,
) -> None:
    x, y = xy
    for ch in label:
        draw.text(
            (round(x), round(y)),
            ch,
            fill=fill,
            font=font,
            stroke_width=stroke_width,
            stroke_fill=stroke_fill,
        )
        box = draw.textbbox((0, 0), ch, font=font, stroke_width=stroke_width)
        x += _roman_glyph_advance(ch, box[2] - box[0])





def _load_template_image(template: str) -> Image.Image:

    entry = get_map_entry(template)

    if not entry:

        raise ValidationError("Desteklenmeyen harita şablonu.")

    if entry.get("source") == "media":
        asset_path = entry.get("path") or entry.get("asset")
    else:
        asset_path = finders.find(entry["asset"])

    if not asset_path:

        raise FileNotFoundError("Harita dosyası bulunamadı.")

    with Image.open(asset_path) as source:
        return _knockout_map_background(source.convert("RGBA"))





def _knockout_map_background(image: Image.Image) -> Image.Image:
    """Clear paper/sea pixels connected to the frame so the watermark shows."""
    image = image.convert("RGBA")
    width, height = image.size
    pix = image.load()

    def is_paper(x: int, y: int) -> bool:
        red, green, blue, alpha = pix[x, y]
        return bool(alpha) and red >= 240 and green >= 240 and blue >= 240

    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    seen = bytearray(width * height)
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1
        if not is_paper(x, y):
            continue
        pix[x, y] = (255, 255, 255, 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return image


_MAP_PAPER = (248, 250, 252, 255)


def _flatten_on_paper(image: Image.Image) -> Image.Image:
    """Deniz şeffaf kalsın diye değil; koyu temada Romen etiket okunur kalsın."""
    paper = Image.new("RGBA", image.size, _MAP_PAPER)
    paper.alpha_composite(image.convert("RGBA"))
    return paper


def render_static_map(template: str) -> bytes:
    image = _flatten_on_paper(_load_template_image(template))
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()





def _hex_to_rgba(color: str) -> tuple[int, int, int, int]:
    value = color.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255


def _draw_map_marker(
    image: Image.Image,
    marker: dict[str, Any],
    *,
    stroke: int,
) -> tuple[float, float, float, float]:
    """Draw marker; return axis-aligned box (left, top, right, bottom)."""
    cx = image.width * marker["x"] / 100
    cy = image.height * marker["y"] / 100
    shape = marker.get("shape") or "ellipse"
    rotation = int(marker.get("rotation") or 0) % 180
    fill = marker["color"]
    if shape == "line":
        x1 = image.width * marker["x"] / 100
        y1 = image.height * marker["y"] / 100
        x2 = image.width * marker["x2"] / 100
        y2 = image.height * marker["y2"] / 100
        thickness = max(2, round(image.width * float(marker.get("width") or 0.5) / 100))
        cap = max(thickness * 1.2, thickness + 2)
        radius = cap / 2
        draw = ImageDraw.Draw(image)
        draw.line([(x1, y1), (x2, y2)], fill=fill, width=thickness)
        for cx, cy in ((x1, y1), (x2, y2)):
            draw.ellipse(
                (cx - radius, cy - radius, cx + radius, cy + radius),
                fill=fill,
            )
        return (
            min(x1, x2) - radius,
            min(y1, y2) - radius,
            max(x1, x2) + radius,
            max(y1, y2) + radius,
        )
    if shape == "circle":
        diameter = image.width * marker["width"] / 100
        radius = diameter / 2
        box = (
            round(cx - radius),
            round(cy - radius),
            round(cx + radius),
            round(cy + radius),
        )
        ImageDraw.Draw(image).ellipse(box, fill=fill)
        return box

    width = image.width * marker["width"] / 100
    height = image.height * marker["height"] / 100
    if rotation == 0:
        box = (
            round(cx - width / 2),
            round(cy - height / 2),
            round(cx + width / 2),
            round(cy + height / 2),
        )
        ImageDraw.Draw(image).ellipse(box, fill=fill)
        return box

    rad = math.radians(rotation)
    aabb_w = abs(width * math.cos(rad)) + abs(height * math.sin(rad))
    aabb_h = abs(width * math.sin(rad)) + abs(height * math.cos(rad))
    box = (
        cx - aabb_w / 2,
        cy - aabb_h / 2,
        cx + aabb_w / 2,
        cy + aabb_h / 2,
    )
    pad = int(max(width, height) * 1.35) + stroke * 2
    overlay = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    ox = oy = pad
    od.ellipse(
        (ox - width / 2, oy - height / 2, ox + width / 2, oy + height / 2),
        fill=_hex_to_rgba(fill),
    )
    overlay = overlay.rotate(-rotation, resample=Image.BICUBIC, center=(ox, oy))
    image.paste(overlay, (round(cx - pad), round(cy - pad)), overlay)
    return (
        round(box[0]),
        round(box[1]),
        round(box[2]),
        round(box[3]),
    )


def _start_end_city(marker: dict[str, Any]) -> tuple[str, str]:
    start = str(marker.get("startLabel") or "").strip()
    end = str(marker.get("endLabel") or "").strip()
    if start or end:
        return start, end
    parts = [
        part.strip()
        for part in str(marker.get("label") or "").replace(",", "·").split("·")
        if part.strip()
    ]
    if not parts:
        return line_endpoint_names(
            float(marker["x"]),
            float(marker["y"]),
            float(marker["x2"]),
            float(marker["y2"]),
        )
    if len(parts) == 1:
        return "", parts[0]
    return parts[0], parts[-1]


def _clamp_label_xy(
    x: float, y: float, width: int, height: int, pad: float
) -> tuple[float, float]:
    return (
        min(width - pad, max(pad, x)),
        min(height - pad, max(pad, y)),
    )


def _draw_named_city(
    draw: ImageDraw.ImageDraw,
    name: str,
    xy: tuple[float, float],
    *,
    font: ImageFont.ImageFont,
    stroke: int,
) -> None:
    box = draw.textbbox((0, 0), name, font=font, stroke_width=stroke)
    tw, th = box[2] - box[0], box[3] - box[1]
    draw.text(
        (round(xy[0] - tw / 2), round(xy[1] - th / 2)),
        name,
        font=font,
        fill="#111827",
        stroke_width=stroke,
        stroke_fill="#ffffff",
    )


def _draw_line_city_labels(image: Image.Image, lines: list[dict[str, Any]]) -> None:
    visible = [item for item in lines if item.get("showLabel") is not False]
    if not visible:
        return
    font = _font(max(22, round(image.width * 0.022)))
    stroke = max(3, round(image.width * 0.003))
    draw = ImageDraw.Draw(image)
    pad = max(18, round(image.width * 0.02))
    hubs: dict[tuple[float, float], tuple[str, float, float]] = {}
    for marker in visible:
        start_name, end_name = _start_end_city(marker)
        x1 = image.width * marker["x"] / 100
        y1 = image.height * marker["y"] / 100
        x2 = image.width * marker["x2"] / 100
        y2 = image.height * marker["y2"] / 100
        key = (round(marker["x"], 1), round(marker["y"], 1))
        if start_name and key not in hubs:
            hubs[key] = (start_name, x1, y1 - image.height * 0.045)
        if not end_name:
            continue
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy) or 1
        extra = image.width * 0.038
        px = x2 + dx / length * extra
        py = y2 + dy / length * extra
        _draw_named_city(
            draw,
            end_name,
            _clamp_label_xy(px, py, image.width, image.height, pad),
            font=font,
            stroke=stroke,
        )
    for name, hx, hy in hubs.values():
        _draw_named_city(
            draw,
            name,
            _clamp_label_xy(hx, hy, image.width, image.height, pad),
            font=font,
            stroke=stroke,
        )


def _draw_standalone_city_labels(
    image: Image.Image, labels: list[dict[str, Any]]
) -> None:
    visible = [
        item
        for item in labels
        if item.get("showLabel") is not False and str(item.get("label") or "").strip()
    ]
    if not visible:
        return
    font = _font(max(22, round(image.width * 0.022)))
    stroke = max(3, round(image.width * 0.003))
    draw = ImageDraw.Draw(image)
    pad = max(18, round(image.width * 0.02))
    for marker in visible:
        name = str(marker.get("label") or "").strip()
        if not name:
            continue
        px = image.width * marker["x"] / 100
        py = image.height * marker["y"] / 100
        _draw_named_city(
            draw,
            name,
            _clamp_label_xy(px, py, image.width, image.height, pad),
            font=font,
            stroke=stroke,
        )


def render_marker_map(

    template: str,

    markers: list[dict[str, Any]],

) -> bytes:

    image = _load_template_image(template).convert("RGBA")

    draw = ImageDraw.Draw(image)

    font = _font(max(68, round(image.width * 0.048)))

    stroke = max(2, round(image.width * 0.002))

    label_stroke = max(4, round(image.width * 0.004))

    gap = max(14, round(image.width * 0.01))



    fills = [item for item in markers if item.get("shape") == "fill"]
    pins = [item for item in markers if item.get("shape") != "fill"]
    draw_province_fills(image, fills)

    roman_index = 0
    lines = []
    city_labels = []
    for marker in pins:
        shape = marker.get("shape")
        if shape == "line":
            _draw_map_marker(image, marker, stroke=stroke)
            lines.append(marker)
            continue
        if shape == "city-label":
            city_labels.append(marker)
            continue
        box = _draw_map_marker(image, marker, stroke=stroke)
        if marker.get("showLabel") is False:
            continue
        roman_index += 1
        cx = image.width * marker["x"] / 100
        cy = image.height * marker["y"] / 100
        draw = ImageDraw.Draw(image)
        label = _roman(roman_index)
        label_width, label_height = _roman_label_size(
            draw, label, font, label_stroke
        )

        side = marker["labelSide"]

        if side == "left":

            tx, ty = box[0] - gap - label_width, cy - label_height / 2

        elif side == "top":

            tx, ty = cx - label_width / 2, box[1] - gap - label_height

        elif side == "bottom":

            tx, ty = cx - label_width / 2, box[3] + gap

        else:

            tx, ty = box[2] + gap, cy - label_height / 2

        _draw_roman_label(
            draw,
            (tx, ty),
            label,
            font=font,
            fill="#111827",
            stroke_width=label_stroke,
            stroke_fill="#ffffff",
        )

    _draw_standalone_city_labels(image, city_labels)
    _draw_line_city_labels(image, lines)
    image = _flatten_on_paper(image)
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()





def render_map_question(

    template: str,

    markers: Any,

) -> bytes:

    normalized = validate_map_markers(template, markers)

    if is_static_template(template):

        return render_static_map(template)

    if is_marker_template(template):

        return render_marker_map(template, normalized)

    raise ValidationError("Desteklenmeyen harita şablonu.")

