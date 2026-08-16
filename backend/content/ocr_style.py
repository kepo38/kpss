"""Görselden kalın / italik / altı çizili tespiti → markdown sarmalama."""

from __future__ import annotations

import re
import statistics
from dataclasses import dataclass

from PIL import Image


@dataclass
class OcrWord:
    text: str
    left: int
    top: int
    width: int
    height: int
    block: int
    par: int
    line: int
    conf: float
    bold: bool = False
    italic: bool = False
    underline: bool = False

    @property
    def line_key(self) -> tuple[int, int, int]:
        return (self.block, self.par, self.line)


_EDGE_PUNCT = re.compile(
    r"^([^\wğüşıöçĞÜŞİÖÇ]*)(.*?)([^\wğüşıöçĞÜŞİÖÇ]*)$",
    re.UNICODE | re.DOTALL,
)


def _pix(img: Image.Image, x: int, y: int) -> int:
    return int(img.getpixel((x, y)))


def _stroke_width(img: Image.Image, left: int, top: int, width: int, height: int) -> float:
    w, h = img.size
    x0, x1 = max(0, left), min(w, left + width)
    y0, y1 = max(0, top), min(h, top + height)
    if x1 - x0 < 4 or y1 - y0 < 4:
        return 0.0
    runs: list[int] = []
    lim = max(2, height // 3)
    for y in range(y0, y1):
        run = 0
        for x in range(x0, x1):
            if _pix(img, x, y) < 150:
                run += 1
            elif run:
                if 1 <= run <= lim:
                    runs.append(run)
                run = 0
        if run and 1 <= run <= lim:
            runs.append(run)
    return float(statistics.median(runs)) if runs else 0.0


def _is_underlined(img: Image.Image, left: int, top: int, width: int, height: int) -> bool:
    """Kutunun alt bandında yatay mürekkep çizgisi var mı?"""
    if width < 28 or height < 12:
        return False
    w, h = img.size
    x0, x1 = max(0, left), min(w, left + width)
    y_start = top + max(2, int(height * 0.70))
    y_end = min(h - 1, top + height + max(2, height // 6))
    if y_end < y_start or x1 <= x0:
        return False

    best = 0.0
    best_y = -1
    span = x1 - x0
    for y in range(y_start, y_end + 1):
        ink = sum(1 for x in range(x0, x1) if _pix(img, x, y) < 150) / span
        if ink > best:
            best, best_y = ink, y
    if best < 0.70 or best_y < 0:
        return False

    run = max_run = 0
    for x in range(x0, x1):
        if _pix(img, x, best_y) < 150:
            run += 1
            max_run = max(max_run, run)
        else:
            run = 0
    frac = max_run / span
    yrel = (best_y - top) / max(1, height)
    return frac >= 0.55 and yrel >= 0.75


def _slant_score(img: Image.Image, left: int, top: int, width: int, height: int) -> float:
    """Pozitif ≈ sağa yatık (italik)."""
    w, h = img.size
    x0, x1 = max(0, left), min(w, left + width)
    y0, y1 = max(0, top), min(h, top + height)
    if x1 - x0 < 10 or y1 - y0 < 12:
        return 0.0

    def centroid_x(ya: int, yb: int) -> float | None:
        sx = n = 0
        for y in range(ya, yb):
            for x in range(x0, x1):
                if _pix(img, x, y) < 150:
                    sx += x
                    n += 1
        return sx / n if n else None

    mid = (y0 + y1) // 2
    top_c = centroid_x(y0, mid)
    bot_c = centroid_x(mid, y1)
    if top_c is None or bot_c is None:
        return 0.0
    return (bot_c - top_c) / max(1, height)


def _looks_like_marker_token(text: str) -> bool:
    s = (text or "").strip().strip(".)")
    if not s or len(s) > 6:
        return False
    if re.fullmatch(r"[A-Ea-e]\s*[\)\]\.\:\-]?", text.strip()):
        return True
    if re.fullmatch(r"[|IlİıVvXxNn1-9]{1,4}", s):
        return True
    return False


def detect_word_styles(img: Image.Image, words: list[OcrWord]) -> None:
    """Kelime kutularına bold / italic / underline bayrakları yazar (yerinde)."""
    if not words:
        return

    measurable = [w for w in words if w.width >= 20 and w.height >= 12]
    strokes = [
        _stroke_width(img, w.left, w.top, w.width, w.height) for w in measurable
    ]
    med_stroke = statistics.median(strokes) if strokes else 5.0

    for w in words:
        if _looks_like_marker_token(w.text):
            continue
        w.underline = _is_underlined(img, w.left, w.top, w.width, w.height)
        sw = _stroke_width(img, w.left, w.top, w.width, w.height)
        w.bold = (
            w.width >= 24
            and sw > 0
            and sw >= med_stroke + 1.4
        )
        slant = _slant_score(img, w.left, w.top, w.width, w.height)
        # İtalik: yüksek eşik; kalın ile karışmasın
        w.italic = (
            (not w.bold)
            and w.width >= 36
            and slant >= 0.28
        )


def _wrap_markdown(text: str, bold: bool, italic: bool, underline: bool) -> str:
    if not text or not (bold or italic or underline):
        return text
    m = _EDGE_PUNCT.match(text)
    if not m:
        return text
    prefix, core, suffix = m.group(1), m.group(2), m.group(3)
    if not core.strip():
        return text
    if bold and italic:
        core = f"***{core}***"
    elif bold:
        core = f"**{core}**"
    elif italic:
        core = f"*{core}*"
    if underline:
        core = f"__{core}__"
    return f"{prefix}{core}{suffix}"


def words_to_styled_text(words: list[OcrWord]) -> str:
    """Satır kırıklı metin; ardışık aynı biçimli kelimeler tek markdown bloğunda."""
    if not words:
        return ""

    lines_out: list[str] = []
    current_key: tuple[int, int, int] | None = None
    line_words: list[OcrWord] = []

    def flush_line() -> None:
        if not line_words:
            return
        parts: list[str] = []
        buf: list[OcrWord] = []
        style = (False, False, False)

        def flush_buf() -> None:
            nonlocal buf, style
            if not buf:
                return
            joined = " ".join(w.text for w in buf)
            parts.append(_wrap_markdown(joined, *style))
            buf = []

        for w in sorted(line_words, key=lambda x: x.left):
            st = (w.bold, w.italic, w.underline)
            if buf and st != style:
                flush_buf()
            if not buf:
                style = st
            buf.append(w)
        flush_buf()
        lines_out.append(" ".join(parts))

    for w in words:
        if current_key is None:
            current_key = w.line_key
        if w.line_key != current_key:
            flush_line()
            line_words = []
            current_key = w.line_key
        line_words.append(w)
    flush_line()
    return "\n".join(lines_out)


def tesseract_words(img: Image.Image, lang: str, psm: int) -> list[OcrWord]:
    import pytesseract

    config = f"--oem 3 --psm {psm} -c preserve_interword_spaces=1"
    data = pytesseract.image_to_data(
        img, lang=lang, config=config, output_type=pytesseract.Output.DICT
    )
    out: list[OcrWord] = []
    n = len(data["text"])
    for i in range(n):
        text = (data["text"][i] or "").strip()
        if not text:
            continue
        try:
            conf = float(data["conf"][i])
        except (TypeError, ValueError):
            conf = -1.0
        if conf < 35:
            continue
        width = int(data["width"][i])
        height = int(data["height"][i])
        if width < 2 or height < 2:
            continue
        out.append(
            OcrWord(
                text=text,
                left=int(data["left"][i]),
                top=int(data["top"][i]),
                width=width,
                height=height,
                block=int(data["block_num"][i]),
                par=int(data["par_num"][i]),
                line=int(data["line_num"][i]),
                conf=conf,
            )
        )
    return out


def extract_styled_text(img: Image.Image, lang: str, psm: int) -> str:
    """Görsel → biçimli OCR metni (markdown)."""
    words = tesseract_words(img, lang, psm)
    detect_word_styles(img, words)
    return words_to_styled_text(words)
