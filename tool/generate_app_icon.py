"""Premium KPSS Odak launcher / splash icon generator."""

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "assets" / "images"
OUT.mkdir(parents=True, exist_ok=True)

INK = (12, 20, 36, 255)
INK_SOFT = (22, 35, 56, 255)
CHAMPAGNE = (201, 168, 108, 255)
CHAMP_LIGHT = (226, 201, 152, 255)
WHITE = (255, 255, 255, 255)


def _font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def draw_icon(size: int = 1024) -> Image.Image:
    img = Image.new("RGBA", (size, size), INK)
    draw = ImageDraw.Draw(img)

    cx = cy = size // 2
    for i in range(18, 0, -1):
        r = int(size * 0.55 * i / 18)
        overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(*INK_SOFT[:3], min(40, 10 + i * 2)),
        )
        img = Image.alpha_composite(img, overlay)
        draw = ImageDraw.Draw(img)

    inset = int(size * 0.08)
    frame = max(2, size // 128)
    for i in range(frame):
        draw.rounded_rectangle(
            [inset + i, inset + i, size - inset - i, size - inset - i],
            radius=int(size * 0.12),
            outline=(*CHAMPAGNE[:3], 190 if i == 0 else 80),
            width=1,
        )

    font_brand = _font(r"C:\Windows\Fonts\timesbd.ttf", int(size * 0.22))
    font_sub = _font(r"C:\Windows\Fonts\georgia.ttf", int(size * 0.055))
    font_mark = _font(r"C:\Windows\Fonts\georgiab.ttf", int(size * 0.028))

    mark = "◆"
    mb = draw.textbbox((0, 0), mark, font=font_mark)
    mw = mb[2] - mb[0]
    draw.text(
        ((size - mw) / 2, size * 0.26),
        mark,
        font=font_mark,
        fill=CHAMPAGNE,
    )

    text = "KPSS"
    tb = draw.textbbox((0, 0), text, font=font_brand)
    tw = tb[2] - tb[0]
    tx = (size - tw) / 2 - tb[0]
    ty = size * 0.34 - tb[1]
    for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
        draw.text(
            (tx + ox, ty + oy),
            text,
            font=font_brand,
            fill=(*CHAMPAGNE[:3], 40),
        )
    draw.text((tx, ty), text, font=font_brand, fill=WHITE)

    line_y = int(size * 0.58)
    lw = int(size * 0.28)
    draw.rectangle(
        [
            (size - lw) / 2,
            line_y,
            (size + lw) / 2,
            line_y + max(2, size // 400),
        ],
        fill=CHAMPAGNE,
    )

    sub = "ODAK"
    chars = list(sub)
    gaps = max(10, size // 70)
    widths = []
    for ch in chars:
        cb = draw.textbbox((0, 0), ch, font=font_sub)
        widths.append(cb[2] - cb[0])
    total = sum(widths) + gaps * (len(chars) - 1)
    x = (size - total) / 2
    sb = draw.textbbox((0, 0), sub, font=font_sub)
    y = size * 0.62 - sb[1]
    for ch, w in zip(chars, widths):
        draw.text((x, y), ch, font=font_sub, fill=CHAMP_LIGHT)
        x += w + gaps

    return img.convert("RGB")


def draw_watermark(size: int = 512) -> Image.Image:
    """Şeffaf arka plan — soru kartı filigranı (koyu zemin üzerinde görünür)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    font_brand = _font(r"C:\Windows\Fonts\timesbd.ttf", int(size * 0.26))
    font_sub = _font(r"C:\Windows\Fonts\georgia.ttf", int(size * 0.065))
    font_mark = _font(r"C:\Windows\Fonts\georgiab.ttf", int(size * 0.034))

    mark = "◆"
    mb = draw.textbbox((0, 0), mark, font=font_mark)
    mw = mb[2] - mb[0]
    draw.text(
        ((size - mw) / 2, size * 0.22),
        mark,
        font=font_mark,
        fill=(*CHAMPAGNE[:3], 165),
    )

    text = "KPSS"
    tb = draw.textbbox((0, 0), text, font=font_brand)
    tw = tb[2] - tb[0]
    tx = (size - tw) / 2 - tb[0]
    ty = size * 0.30 - tb[1]
    draw.text((tx, ty), text, font=font_brand, fill=(*CHAMP_LIGHT[:3], 120))

    line_y = int(size * 0.56)
    lw = int(size * 0.30)
    draw.rectangle(
        [
            (size - lw) / 2,
            line_y,
            (size + lw) / 2,
            line_y + max(2, size // 256),
        ],
        fill=(*CHAMPAGNE[:3], 150),
    )

    sub = "ODAK"
    chars = list(sub)
    gaps = max(8, size // 64)
    widths = []
    for ch in chars:
        cb = draw.textbbox((0, 0), ch, font=font_sub)
        widths.append(cb[2] - cb[0])
    total = sum(widths) + gaps * (len(chars) - 1)
    x = (size - total) / 2
    sb = draw.textbbox((0, 0), sub, font=font_sub)
    y = size * 0.60 - sb[1]
    for ch, w in zip(chars, widths):
        draw.text((x, y), ch, font=font_sub, fill=(*CHAMP_LIGHT[:3], 145))
        x += w + gaps

    inset = int(size * 0.06)
    draw.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=int(size * 0.10),
        outline=(*CHAMPAGNE[:3], 110),
        width=max(2, size // 170),
    )

    return img


def main() -> None:
    source = OUT / "kpss_brand_source.png"
    if source.is_file():
        subprocess.run(
            [sys.executable, str(Path(__file__).with_name("import_brand_logo.py"))],
            check=True,
        )
        return

    icon = draw_icon(1024)
    icon.save(OUT / "app_icon.png", "PNG")
    icon.save(OUT / "kpss_logo.png", "PNG")
    watermark = draw_watermark(640)
    watermark.save(OUT / "kpss_watermark.png", "PNG")
    print(f"Wrote {OUT / 'app_icon.png'}, kpss_logo.png, kpss_watermark.png")


if __name__ == "__main__":
    main()
