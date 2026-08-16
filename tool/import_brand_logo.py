"""Import the official KPSS Odak brand artwork into app assets."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "images"
SOURCE_CANDIDATES = [
    OUT / "kpss_brand_source.png",
    Path.home()
    / ".cursor"
    / "projects"
    / "c-Users-halit-Projects-kpss-akademi"
    / "assets"
    / "c__Users_halit_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_Gemini_Generated_Image_wa4gmvwa4gmvwa4g-fc756685-5655-4326-b09b-eb3ec3ef4c2c.png",
]

INK = (12, 20, 36, 255)


def _find_source() -> Path:
    for path in SOURCE_CANDIDATES:
        if path.is_file():
            return path
    raise FileNotFoundError(
        "Brand source not found. Save the logo as assets/images/kpss_brand_source.png"
    )


def _remove_light_background(img: Image.Image, threshold: int = 215) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            brightness = (r + g + b) / 3
            if brightness >= threshold:
                pixels[x, y] = (r, g, b, 0)
            elif brightness >= threshold - 28:
                fade = int(255 * (threshold - brightness) / 28)
                pixels[x, y] = (r, g, b, min(a, fade))
    return rgba


def _trim_transparent(img: Image.Image, pad: int = 8) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    left, top, right, bottom = bbox
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(img.width, right + pad)
    bottom = min(img.height, bottom + pad)
    return img.crop((left, top, right, bottom))


def _fit_on_canvas(
    logo: Image.Image,
    size: int,
    *,
    background: tuple[int, int, int, int] | None = None,
    scale: float = 0.88,
) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    target = int(size * scale)
    fitted = logo.copy()
    fitted.thumbnail((target, target), Image.Resampling.LANCZOS)
    x = (size - fitted.width) // 2
    y = (size - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def _fit_launcher_icon(
    logo: Image.Image,
    size: int,
    *,
    background: tuple[int, int, int, int] | None = None,
    height_fill: float = 0.84,
) -> Image.Image:
    """Yatay logoyu kare launcher ikonunda daha büyük gösterir."""
    canvas = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    target_h = max(1, int(size * height_fill))
    aspect = logo.width / logo.height
    new_h = target_h
    new_w = max(1, int(target_h * aspect))
    fitted = logo.resize((new_w, new_h), Image.Resampling.LANCZOS)
    x = (size - new_w) // 2
    y = (size - new_h) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def _watermark_from_logo(logo: Image.Image, size: int = 768) -> Image.Image:
    fitted = _fit_on_canvas(logo, size, scale=0.92)
    pixels = fitted.load()
    for y in range(fitted.height):
        for x in range(fitted.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            pixels[x, y] = (r, g, b, int(a * 0.72))
    return fitted


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    source = _find_source()
    archive = OUT / "kpss_brand_source.png"
    if source.resolve() != archive.resolve():
        Image.open(source).save(archive, "PNG")

    raw = Image.open(archive)
    logo = _trim_transparent(_remove_light_background(raw))

    app_icon = _fit_launcher_icon(logo, 1024, background=INK, height_fill=0.84)
    app_icon_foreground = _fit_launcher_icon(logo, 1024, height_fill=0.84)
    splash_logo = _fit_on_canvas(logo, 1024, scale=0.90)
    watermark = _watermark_from_logo(logo, 768)

    app_icon.save(OUT / "app_icon.png", "PNG")
    app_icon_foreground.save(OUT / "app_icon_foreground.png", "PNG")
    splash_logo.save(OUT / "kpss_logo.png", "PNG")
    watermark.save(OUT / "kpss_watermark.png", "PNG")
    print(
        "Wrote app_icon.png, app_icon_foreground.png, kpss_logo.png, "
        f"kpss_watermark.png from {archive.name}"
    )


if __name__ == "__main__":
    main()
