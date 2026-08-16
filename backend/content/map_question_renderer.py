"""Validation and server-side rendering for coordinate map questions."""

from __future__ import annotations



import json

import re

from io import BytesIO

from typing import Any



from django.contrib.staticfiles import finders

from django.core.exceptions import ValidationError

from PIL import Image, ImageDraw, ImageFont



from .map_catalog import get_map_entry, is_marker_template, is_static_template





MAX_MARKERS = 12

DEFAULT_COLOR = "#ef4444"

ALLOWED_LABEL_SIDES = {"left", "right", "top", "bottom"}

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

        # Harita yokken kalan işaret verisini yok say (normal soru kaydı).

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

        raise ValidationError("Harita sorusunda en az bir işaret olmalı.")

    if len(markers) > MAX_MARKERS:

        raise ValidationError(f"En fazla {MAX_MARKERS} işaret eklenebilir.")



    normalized: list[dict[str, Any]] = []

    for index, raw in enumerate(markers, start=1):

        if not isinstance(raw, dict):

            raise ValidationError(f"{index}. işaret geçersiz.")

        color = str(raw.get("color") or DEFAULT_COLOR).strip()

        if not HEX_COLOR.fullmatch(color):

            raise ValidationError(f"{index}. işaret rengi geçersiz.")

        label_side = str(raw.get("labelSide") or "right").strip()

        if label_side not in ALLOWED_LABEL_SIDES:

            raise ValidationError(f"{index}. etiket yönü geçersiz.")

        normalized.append(

            {

                "x": _number(raw.get("x"), f"{index}. işaret X", 0, 100),

                "y": _number(raw.get("y"), f"{index}. işaret Y", 0, 100),

                "width": _number(

                    raw.get("width", 4.5),

                    f"{index}. işaret genişliği",

                    1,

                    15,

                ),

                "height": _number(

                    raw.get("height", 3.5),

                    f"{index}. işaret yüksekliği",

                    1,

                    15,

                ),

                "color": color.lower(),

                "labelSide": label_side,

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

    try:

        return ImageFont.truetype("DejaVuSans.ttf", size)

    except OSError:

        return ImageFont.load_default(size=size)





def _load_template_image(template: str) -> Image.Image:

    entry = get_map_entry(template)

    if not entry:

        raise ValidationError("Desteklenmeyen harita şablonu.")

    asset_path = finders.find(entry["asset"])

    if not asset_path:

        raise FileNotFoundError("Harita dosyası bulunamadı.")

    with Image.open(asset_path) as source:

        return source.convert("RGB")





def render_static_map(template: str) -> bytes:

    image = _load_template_image(template)

    output = BytesIO()

    image.save(output, format="PNG", optimize=True)

    return output.getvalue()





def render_marker_map(

    template: str,

    markers: list[dict[str, Any]],

) -> bytes:

    image = _load_template_image(template)

    draw = ImageDraw.Draw(image)

    font = _font(max(28, round(image.width * 0.025)))

    stroke = max(2, round(image.width * 0.002))

    gap = max(10, round(image.width * 0.008))



    for index, marker in enumerate(markers, start=1):

        cx = image.width * marker["x"] / 100

        cy = image.height * marker["y"] / 100

        width = image.width * marker["width"] / 100

        height = image.height * marker["height"] / 100

        box = (

            round(cx - width / 2),

            round(cy - height / 2),

            round(cx + width / 2),

            round(cy + height / 2),

        )

        draw.ellipse(

            box,

            fill=marker["color"],

            outline="#7f1d1d",

            width=stroke,

        )



        label = _roman(index)

        label_box = draw.textbbox((0, 0), label, font=font, stroke_width=1)

        label_width = label_box[2] - label_box[0]

        label_height = label_box[3] - label_box[1]

        side = marker["labelSide"]

        if side == "left":

            tx, ty = box[0] - gap - label_width, cy - label_height / 2

        elif side == "top":

            tx, ty = cx - label_width / 2, box[1] - gap - label_height

        elif side == "bottom":

            tx, ty = cx - label_width / 2, box[3] + gap

        else:

            tx, ty = box[2] + gap, cy - label_height / 2

        draw.text(

            (round(tx), round(ty)),

            label,

            fill="#111827",

            font=font,

            stroke_width=1,

            stroke_fill="#ffffff",

        )



    output = BytesIO()

    image.save(output, format="PNG", optimize=True)

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

