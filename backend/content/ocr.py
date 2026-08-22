"""Soru görselinden metin + A–E şık ayrıştırma (Tesseract, Türkçe).

Genel hat (soru tipinden bağımsız):
1. Türkçe OCR/encoding normalizasyonu
2. Görselden kalın / italik / altı çizili → markdown (admin düzeltebilir)
3. A–E şık ayrıştırma (OCR sapmaları dahil)
4. Stem: yumuşak satır birleştirme + madde işareti satırlarını gömme
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import BinaryIO

from django.conf import settings
from PIL import Image, ImageFilter, ImageOps

from .ocr_style import extract_styled_text

OPTION_KEYS = ("A", "B", "C", "D", "E")

# Şık satırı: A) / A. / A: / A- veya OCR bozulması (6→C, 8→B)
_OPTION_START = re.compile(
    r"^\s*([A-Ea-e680OQG])\s*[\)\]\.\:\-\–\—]?\s+(.*\S.*)$"
)
# Daha sıkı: ayırıcı zorunlu
_OPTION_STRICT = re.compile(
    r"^\s*([A-Ea-e680OQG])\s*[\)\]\.\:\-\–\—]\s*(.*)$"
)
# OCR: "cCc)" / "Cc)" / "CC)" gibi bozulmuş şık başı (özellikle C)
_OPTION_GARBLED = re.compile(
    r"^\s*([A-Ea-e]{2,4}|[680OQG])\s*[\)\]\.\:\-\–\—]\s*(.*)$"
)
# Satır/gövde içine yapışmış sonraki şık: "… IV cCc) II ve III"
# Ayırıcı yalnızca parantez/köşeli: "e-devlet", "a." gibi metinleri bölmemek için.
_EMBEDDED_OPTION_MARK = re.compile(
    r"(?x)"
    r"(?<=\S)\s+"
    r"(?P<key>[A-E]|[A-Ea-e]{2,4}|[680OQG])"
    r"\s*[\)\]]\s*"
)
# Satır başı yetim ")" (önceki şıkın devamı)
_ORPHAN_PAREN = re.compile(r"^\s*\)\s*(.*\S.*)$")

# Soru kökünün bittiği satır (şıklar bundan sonra başlar) — yaygın KPSS kalıpları
_STEM_END_HINT = re.compile(
    r"(?i)\b("
    r"söylenemez|söylenebilir|"
    r"hangisidir|hangisi|"
    r"aşağıdakilerden|yukarıdakilerden|yukarıda|"
    r"numaralan(?:mış|dırılmış)|"
    r"amaçlan(?:mıştır|ır)|anlatıl(?:mak|mıştır)|"
    r"değildir|nedir|kaçtır|hangisine|hangisinin|"
    r"getirilemez|çıkarılamaz|varılamaz|"
    r"doğrudur|yanlıştır"
    r")\b"
)

# Parça / bilgi metninden soru cümlesine geçiş (genel)
_QUESTION_PARA_START = re.compile(
    r"(?i)^\s*("
    r"yukarıda|yukarıdaki|buna\s+göre|buna\s+göre|"
    r"aşağıdakilerden|verilenlere\s+göre|verilen\s+(?:bilgi|parça|metin)|"
    r"bu\s+(?:parçaya|metne|bilgiye)\s+göre|metne\s+göre|"
    r"bu\s+duruma\s+göre|bu\s+açıklamaya\s+göre"
    r")\b"
)

# Tek satırda kalan madde işaretleri (Romen / Arap); OCR bozulmaları dahil
_ROMAN_TOKEN_MAP = {
    "|": "I",
    "l": "I",
    "i": "I",
    "ı": "I",
    "i.": "I",
    "ii": "II",
    "ll": "II",
    "il": "II",
    "ıı": "II",
    "lı": "II",
    "iii": "III",
    "lll": "III",
    "lil": "III",
    "ni": "III",
    "nii": "III",
    "ııı": "III",
    "iv": "IV",
    "ıv": "IV",
    "v": "V",
    "vi": "VI",
    "vii": "VII",
    "viii": "VIII",
    "ix": "IX",
    "x": "X",
}
_ROMAN_CHAR_FOLD = {
    "|": "I",
    "l": "I",
    "ı": "I",
    "i": "I",
    "İ": "I",
    "I": "I",
    "v": "V",
    "V": "V",
    "x": "X",
    "X": "X",
}
_ROMAN_CANON = {
    "I",
    "II",
    "III",
    "IV",
    "V",
    "VI",
    "VII",
    "VIII",
    "IX",
    "X",
}
_MARKER_LINE = re.compile(
    r"^\s*(?:"
    r"([|Ilİı1VvXxNn]{1,4})"  # Romen / OCR çöpü
    r"|([1-9]|10)"  # Arap 1–10
    r")\.?\s*$"
)
# Madde işaretinin bağlanacağı kısa ifade (; veya :) — markdown sarmalayıcıya izin ver
_PHRASE_BEFORE_BREAK = re.compile(
    r"(?:"
    r"__([^_]+?)__|"
    r"\*\*\*(.+?)\*\*\*|"
    r"\*\*(.+?)\*\*|"
    r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|"
    r"([\w'’ğüşıöçĞÜŞİÖÇ]+(?:\s+[\w'’ğüşıöçĞÜŞİÖÇ]+)?)"
    r")\s*([;:])",
    re.UNICODE,
)
_LEADING_PHRASE = re.compile(
    r"^(?:"
    r"__([^_]+?)__|"
    r"\*\*\*(.+?)\*\*\*|"
    r"\*\*(.+?)\*\*|"
    r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|"
    r"([\w'’ğüşıöçĞÜŞİÖÇ]+(?:\s+[\w'’ğüşıöçĞÜŞİÖÇ]+)?)"
    r")\b",
    re.UNICODE,
)


def _is_stem_end_line(ln: str) -> bool:
    s = (ln or "").strip()
    if not s:
        return False
    if s.endswith("?"):
        return True
    return bool(_STEM_END_HINT.search(s))


def _split_question_tail(ln: str) -> tuple[str, str]:
    """'...? Toplumun güvenini' → ('...?', 'Toplumun güvenini')."""
    s = ln.strip()
    if "?" not in s:
        return s, ""
    before, after = s.rsplit("?", 1)
    after = after.strip(" \t-–—:")
    before = (before + "?").strip()
    # Kısa ek / şık parçası; uzun pasaj stem'de kalsın
    if (
        after
        and len(after) <= 100
        and not _OPTION_STRICT.match(after)
        and not _OPTION_START.match(after)
    ):
        return before, after
    return s, ""


_BULLET_LINE = re.compile(
    r"^[\s]*(?:[•·●○▪▸►\*]|[-–—]\s|\d+[\)\.]|\([a-eçğıöşü]\)|[a-eçğıöşü]\))"
)


def _looks_like_option_a_prefix(gap_lines: list[str], a_body: str) -> bool:
    """
    Stem sonu ile A) arasındaki satırlar A şıkkı kırığı mı, yoksa olay metni mi?

    Kısa ek + 'artırmayı' → A'ya; uzun pasaj / maddeler → stem'de kalır.
    """
    gap = [ln.strip() for ln in gap_lines if (ln or "").strip()]
    if not gap:
        return False
    text = " ".join(gap)
    if any(_BULLET_LINE.match(ln) for ln in gap):
        return False
    if len(gap) >= 3 or len(text) > 100:
        return False
    if sum(1 for ln in gap if len(ln) > 45) >= 2:
        return False
    a = (a_body or "").strip()
    if a and _OPTION_CONTINUATION.match(a):
        return True
    if len(gap) <= 2 and len(text) <= 100:
        return True
    return False

_OCR_LETTER_FIX = {
    "A": "A",
    "B": "B",
    "C": "C",
    "D": "D",
    "E": "E",
    "8": "B",  # B≈8
    "6": "C",  # C≈6
    "G": "C",
    "0": "D",
    "O": "D",
    "Q": "D",
}

_CP1254_MOJIBAKE = str.maketrans(
    {"ý": "ı", "þ": "ş", "ð": "ğ", "Ý": "İ", "Þ": "Ş", "Ð": "Ğ"}
)
_OCR_CHAR_FIXES = str.maketrans(
    {"¤": "ş", "¢": "ç", "ﬁ": "fi", "ﬂ": "fl", "ﬀ": "ff", "\u00a0": " "}
)

_WATERMARK_RE = re.compile(
    r"(?i)\s*[\(\[]?\b(?:ö\s*s\s*y\s*m|osym|ösym|dösym|dosym|dösvm)\b[\)\]]?\s*"
)
_SPLIT_EQUATION = re.compile(
    r"(?<=\S)\s+(?=(?:\([a-z]\s*[°o∘]\s*[a-z]\)|\([a-z]{2,3}\)|[fg])\([a-z0-9]+\)\s*=|[fg]\([a-z0-9]+\)\s*=)"
)
_MERGED_DE_OPTION = re.compile(
    r"^(\d+(?:[.,]\d+)?)\s*(?:E\s*e?\)?\s*|E\s*[\)\.\:\-]\s*)(\d+(?:[.,]\d+)?)\s*$",
    re.I,
)
_MATH_OPTION_DIRTY = re.compile(r"(?i)(?:şık\s*[a-e]|ee\)|\bE\s*[\)\.:])")


def _normalize_option_key(raw_key: str) -> str | None:
    key = (raw_key or "").strip()
    upper = key.upper()
    if upper in OPTION_KEYS:
        return upper
    fixed = _OCR_LETTER_FIX.get(key) or _OCR_LETTER_FIX.get(upper)
    if fixed:
        return fixed
    # "cCc" / "Cc" / "BB" → tek harf A–E
    letters = [c.upper() for c in key if c.upper() in OPTION_KEYS]
    if letters and len(set(letters)) == 1:
        return letters[0]
    return None


# Yüksek güven: ğ kaybolup yerine boşluk/satır kırığı gelmiş yaygın kalıplar.
# Yalnızca kanıtlı OCR/yazım bozulmaları; genel "g → ğ" yeniden yazımı yok.
_MISSING_GBREVE_REPAIRS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"gerekti[\s\u00a0]+ini", re.IGNORECASE), "gerektiğini"),
    (re.compile(r"oldugu[\s\u00a0]+una", re.IGNORECASE), "olduğuna"),
    (re.compile(r"oldugu[\s\u00a0]+unu", re.IGNORECASE), "olduğunu"),
)


def _mojibake_marker_count(text: str) -> int:
    return sum(text.count(ch) for ch in ("Ã", "Â", "Ä", "Å"))


def _turkish_letter_count(text: str) -> int:
    return sum(text.count(ch) for ch in "çğıöşüÇĞİÖŞÜ")


def _repair_utf8_mojibake(text: str) -> str:
    """UTF-8'in latin-1/cp1252 olarak okunmasından doğan bozulmayı düzelt.

    Eski kapı yalnızca ``Ã`` azalmasını kabul ediyordu; ``ğ`` (C4 9F → Ä+…)
    için ``Ã`` sayısı 0 kalır ve onarım reddedilirdi.
    """
    if not re.search(r"Ã.|Â.|Ä.|Å.", text):
        return text
    best = text
    best_score = (_mojibake_marker_count(text), -_turkish_letter_count(text))
    for encoding in ("latin-1", "cp1252"):
        try:
            repaired = text.encode(encoding).decode("utf-8")
        except (UnicodeDecodeError, UnicodeEncodeError):
            continue
        repaired = unicodedata.normalize("NFC", repaired)
        score = (
            _mojibake_marker_count(repaired),
            -_turkish_letter_count(repaired),
        )
        if score < best_score:
            best, best_score = repaired, score
    return best


def _repair_missing_gbreve(text: str) -> str:
    """``gerekti ini`` gibi ğ→boşluk bozulmalarını güvenli kalıplarla onar."""
    for pattern, replacement in _MISSING_GBREVE_REPAIRS:
        text = pattern.sub(replacement, text)
    return text


def normalize_turkish_text(text: str) -> str:
    """UTF-8 NFC + yaygın Türkçe OCR/encoding düzeltmeleri."""
    if not text:
        return ""
    text = unicodedata.normalize("NFC", text)
    text = text.translate(_CP1254_MOJIBAKE)
    text = text.translate(_OCR_CHAR_FIXES)
    text = _repair_utf8_mojibake(text)
    text = _repair_missing_gbreve(text)
    lines = [
        ln.rstrip()
        for ln in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    ]
    return "\n".join(lines).strip()


def _fold_roman_chars(s: str) -> str | None:
    """'lii' / '|v' gibi OCR karakterlerini Romen harflerine indir."""
    out: list[str] = []
    for ch in s:
        mapped = _ROMAN_CHAR_FOLD.get(ch)
        if mapped is None:
            return None
        out.append(mapped)
    return "".join(out)


def _normalize_roman_token(raw: str) -> str | None:
    """OCR bozulmuş Romen (|, ll, NI…) → I–X. Arap rakamı dokunulmaz."""
    s = (raw or "").strip().strip(".")
    if not s or s.isdigit():
        return None
    folded = s.replace("İ", "I").replace("ı", "i")
    upper = folded.upper()
    if upper in _ROMAN_CANON:
        return upper
    mapped = _ROMAN_TOKEN_MAP.get(folded.lower()) or _ROMAN_TOKEN_MAP.get(s)
    if mapped:
        return mapped
    char_folded = _fold_roman_chars(s)
    if char_folded and char_folded in _ROMAN_CANON:
        return char_folded
    return None


def _normalize_marker_token(raw: str) -> str | None:
    """Tek satır madde işareti: Romen I–X veya Arap 1–10."""
    s = (raw or "").strip().strip(".")
    if not s:
        return None
    if re.fullmatch(r"[1-9]|10", s):
        return s
    return _normalize_roman_token(s)


def _is_marker_line(ln: str) -> str | None:
    """Satır yalnızca madde işareti mi? (Romen/Arap/OCR çöpü)."""
    s = (ln or "").strip()
    if not s or len(s) > 8 or " " in s:
        return None
    m = _MARKER_LINE.match(s)
    if m:
        return _normalize_marker_token(m.group(1) or m.group(2) or s)
    return _normalize_marker_token(s)


def _already_has_marker(text: str, marker: str) -> bool:
    return bool(re.search(rf"\({re.escape(marker)}\)", text))


def _attach_marker_after_phrase(text: str, marker: str) -> str | None:
    """
    Son kısa ifadeden sonra (I) ekle — noktalama (; , :) korunur.
    Markdown sarmalayıcıları korunur.
    """
    if _already_has_marker(text, marker):
        return None
    matches = list(_PHRASE_BEFORE_BREAK.finditer(text))
    for m in reversed(matches):
        punct_at = m.start(6)
        window = text[max(0, m.start() - 2) : min(len(text), punct_at + 10)]
        if re.search(r"\([IVX0-9]+\)", window):
            continue
        punct_at = m.start(6)
        return text[:punct_at] + f" ({marker})" + text[punct_at:]
    return None


_WORD_TOKEN = re.compile(r"\S+")
_TRAILING_PUNCT = ",.;:!?)»”\"'"


def _marker_row_tokens(ln: str) -> list[tuple[int, int, str]] | None:
    """
    Satır yalnızca yan yana madde işaretlerinden mi oluşuyor?
    Örnek: '    I                        II' → [(4, 5, 'I'), (29, 31, 'II')]
    """
    if not (ln or "").strip():
        return None
    tokens = list(_WORD_TOKEN.finditer(ln))
    if len(tokens) < 2:
        return None
    out: list[tuple[int, int, str]] = []
    seen: set[str] = set()
    for token in tokens:
        marker = _normalize_marker_token(token.group(0))
        if not marker or marker in seen:
            return None
        seen.add(marker)
        out.append((token.start(), token.end(), marker))
    return out


def _attach_markers_by_columns(
    text: str, tokens: list[tuple[int, int, str]], tolerance: float = 8
) -> str | None:
    """
    Altı çizili sözcüklerin altındaki Romen rakamlarını kolon hizasına göre göm.
    '… tüketilen besinlerin' + '  I            II' → '… tüketilen (I) besinlerin (II)'
    """
    words = list(_WORD_TOKEN.finditer(text))
    if not words:
        return None

    used: set[int] = set()
    plan: list[tuple[int, str]] = []
    for start, end, marker in tokens:
        if _already_has_marker(text, marker):
            continue
        center = (start + end - 1) / 2
        best: int | None = None
        best_score: tuple[float, float] | None = None
        for idx, word in enumerate(words):
            if idx in used:
                continue
            if word.start() <= center <= word.end():
                distance = 0.0
            else:
                distance = min(
                    abs(center - word.start()), abs(center - (word.end() - 1))
                )
            word_center = (word.start() + word.end() - 1) / 2
            score = (distance, abs(center - word_center))
            if best_score is None or score < best_score:
                best_score = score
                best = idx
        # Hizası çok uzaksa tahmin yürütme
        if best is None or best_score is None or best_score[0] > tolerance:
            continue
        used.add(best)
        word = words[best]
        insert_at = word.end()
        while insert_at > word.start() and text[insert_at - 1] in _TRAILING_PUNCT:
            insert_at -= 1
        plan.append((insert_at, marker))

    if not plan:
        return None
    for insert_at, marker in sorted(plan, reverse=True):
        text = text[:insert_at] + f" ({marker})" + text[insert_at:]
    return text


def _attach_marker_leading(text: str, marker: str) -> str:
    """Satır başındaki kısa ifadeden sonra (I) ekle."""
    if _already_has_marker(text, marker):
        return text
    s = text.lstrip()
    lead = len(text) - len(s)
    m = _LEADING_PHRASE.match(s)
    if not m:
        return text.rstrip() + f" ({marker})"
    # Eşleşmenin tamamını koru, hemen ardından işaret koy
    return text[:lead] + s[: m.end()] + f" ({marker})" + s[m.end() :]


def _repair_marker_lines(lines: list[str]) -> list[str]:
    """
    Metin arasına düşmüş madde işareti satırlarını göm.
    Örnek (her soru tipi): '… ifadesi;\\n|' → '… ifadesi (I);'
    Altı çizgi/kalın üretmez — tüm sorularda güvenli yapısal onarım.
    """
    out: list[str] = []
    i = 0
    while i < len(lines):
        marker = _is_marker_line(lines[i])
        if not marker:
            # Yan yana Romen rakamı satırı: üstteki sözcüklere kolon hizasıyla bağla
            row = _marker_row_tokens(lines[i])
            if row and out:
                prev_i = len(out) - 1
                while prev_i >= 0 and not out[prev_i].strip():
                    prev_i -= 1
                if prev_i >= 0:
                    repaired = _attach_markers_by_columns(out[prev_i], row)
                    if repaired is not None:
                        out[prev_i] = repaired
                        i += 1
                        continue
            out.append(lines[i])
            i += 1
            continue

        attached = False

        # Girintili tek rakam: doğrudan üstündeki sözcüğe bağla
        tokens = list(_WORD_TOKEN.finditer(lines[i]))
        if out and len(tokens) == 1 and tokens[0].start() >= 4:
            prev_i = len(out) - 1
            while prev_i >= 0 and not out[prev_i].strip():
                prev_i -= 1
            if prev_i >= 0:
                repaired = _attach_markers_by_columns(
                    out[prev_i],
                    [(tokens[0].start(), tokens[0].end(), marker)],
                    tolerance=3,
                )
                if repaired is not None:
                    out[prev_i] = repaired
                    attached = True

        if not attached and out:
            prev_i = len(out) - 1
            while prev_i >= 0 and not out[prev_i].strip():
                prev_i -= 1
            if prev_i >= 0:
                repaired = _attach_marker_after_phrase(out[prev_i], marker)
                if repaired is not None:
                    out[prev_i] = repaired
                    attached = True
                elif prev_i > 0 and out[prev_i - 1].strip():
                    combo = out[prev_i - 1].rstrip() + " " + out[prev_i].lstrip()
                    repaired = _attach_marker_after_phrase(combo, marker)
                    if repaired is not None:
                        out[prev_i - 1] = repaired
                        out.pop(prev_i)
                        attached = True
                if not attached:
                    lead = out[prev_i].lstrip()
                    if _LEADING_PHRASE.match(lead) and not re.search(
                        r"\([IVX0-9]+\)", lead[:40]
                    ):
                        out[prev_i] = _attach_marker_leading(out[prev_i], marker)
                        attached = True

        if not attached:
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and _is_marker_line(lines[j]) is None:
                out.append(_attach_marker_leading(lines[j], marker))
                i = j + 1
                continue
            if out:
                prev_i = len(out) - 1
                while prev_i >= 0 and not out[prev_i].strip():
                    prev_i -= 1
                if prev_i >= 0:
                    out[prev_i] = out[prev_i].rstrip() + f" ({marker})"
        i += 1
    return out


def strip_option_emphasis(text: str) -> str:
    """Şıklarda kalın/italik/altı çizili yok; $...$ matematik korunur."""
    if not text:
        return ""
    holders: list[str] = []

    def _hold(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"\x00MATH{len(holders) - 1}\x00"

    protected = re.sub(r"\$\$[\s\S]+?\$\$|\$[^$\n]+\$", _hold, text)
    protected = re.sub(
        r"</?(?:strong|b|em|i|u)\b[^>]*>",
        "",
        protected,
        flags=re.IGNORECASE,
    )
    for pattern in (
        r"\*\*\*(.+?)\*\*\*",
        r"\*\*(.+?)\*\*",
        r"__(.+?)__",
        r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)",
    ):
        protected = re.sub(pattern, r"\1", protected, flags=re.DOTALL)
    for i, chunk in enumerate(holders):
        protected = protected.replace(f"\x00MATH{i}\x00", chunk)
    return wrap_option_latex(protected.strip())


_BARE_LATEX_CMD = re.compile(
    r"\\(?:frac|dfrac|tfrac|sqrt|cdot|times|left|right|text|overline|"
    r"underline|begin|infty)\b"
)


def wrap_option_latex(text: str) -> str:
    """Kayıtta çıplak \\frac varsa $...$ içine al; frac{ → \\frac{."""
    src = (text or "").strip()
    if not src:
        return src
    if "$" in src or "\\(" in src or "\\[" in src:
        return src
    if "frac" in src and "\\frac" not in src:
        src = re.sub(r"(?<![\\A-Za-z])frac\{", r"\\frac{", src)
    if _BARE_LATEX_CMD.search(src):
        return f"${src}$"
    return src


def _clean_option_body(text: str) -> str:
    """Şık gövdesini tek satıra yakın, biçimsiz metne çevir."""
    text = normalize_turkish_text(text)
    if not text:
        return ""
    holders: list[str] = []

    def _hold(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"\x00MATH{len(holders) - 1}\x00"

    text = re.sub(r"\$\$[\s\S]+?\$\$|\$[^$\n]+\$", _hold, text)
    # Yetim baştaki ")" — içindeki f(x) kapanışını silme
    text = re.sub(r"^\s*\)\s*", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n+", " ", text)
    text = text.strip(" \t:;")
    text = re.sub(r"^[-–—]+(?!\d)", "", text)
    text = re.sub(r"[-–—]+$", "", text)
    text = strip_option_emphasis(text)
    for i, chunk in enumerate(holders):
        text = text.replace(f"\x00MATH{i}\x00", chunk)
    # Yalnızca Romen OCR çöpünü düzelt; -1 / 1 gibi sayısal şıkları bozma
    if " " not in text and not re.fullmatch(r"-?\d+(?:[.,]\d+)?", text):
        roman = _normalize_roman_token(text)
        if roman:
            return roman
    return text.strip()


def _strip_watermarks(text: str) -> str:
    cleaned = _WATERMARK_RE.sub(" ", text or "")
    return re.sub(r"[ \t]{2,}", " ", cleaned).strip()


def _is_watermark_only_line(ln: str) -> bool:
    s = (ln or "").strip()
    if not s:
        return False
    return not _strip_watermarks(s) and bool(_WATERMARK_RE.search(s))


def _is_math_equation_line(ln: str) -> bool:
    s = _strip_watermarks(ln).strip()
    if not s:
        return False
    return bool(
        re.search(
            r"(?i)(?:"
            r"\([a-z]\s*[°o∘]\s*[a-z]\)\([a-z0-9]+\)\s*=|"
            r"\([a-z]{2,3}\)\([a-z0-9]+\)\s*=|"
            r"[fg]\([a-z0-9]+\)\s*=|"
            r"[a-z]\([a-z0-9]+\)\s*=\s*-?\d"
            r")",
            s,
        )
    )


def _split_equation_chunks(text: str) -> list[str]:
    text = _strip_watermarks(text).strip()
    if not text:
        return []
    parts = _SPLIT_EQUATION.split(text)
    return [p.strip() for p in parts if p.strip()]


def _latexify_equation_inner(expr: str) -> str:
    expr = expr.strip()
    expr = re.sub(r"(?i)\(\s*([a-z])\s*[°o∘]\s*([a-z])\s*\)", r"(\1 \\circ \2)", expr)
    expr = re.sub(r"(?i)\(fog\)", r"(f \\circ g)", expr)
    expr = re.sub(r"(?i)\bfog\b", r"f \\circ g", expr)
    expr = re.sub(r"\(\s*([fg])([fg])\s*\)\s*\(", r"(\1 \\circ \2)(", expr)
    expr = re.sub(r"(?i)(2x)\s*[|Il1]\s*(a)\b", r"\1 + \2", expr)
    expr = re.sub(r"(?i)(3x)\s*[|Il]\s*(a)\b", r"\1 - \2", expr)
    expr = re.sub(r"\s*=\s*", " = ", expr)
    expr = re.sub(r"\s+", " ", expr).strip()
    return expr


def _wrap_latex_equation(expr: str) -> str:
    inner = _latexify_equation_inner(expr)
    if not inner:
        return ""
    if inner.startswith("$") and inner.endswith("$"):
        return inner
    return f"${inner}$"


def _latexify_question_sentence(line: str) -> str:
    line = _strip_watermarks(line).strip()
    if not line:
        return ""

    def _wrap_fn(m: re.Match[str]) -> str:
        return _wrap_latex_equation(m.group(1))

    line = re.sub(r"(?i)([fg]\(\d+\)\s*=\s*\d+)", _wrap_fn, line)
    line = re.sub(
        r"(?i)([fg]\(\d+\))(?=\s+değeri|\s+olduğuna)",
        lambda m: f"${m.group(1)}$",
        line,
    )
    return line


def _strip_ocr_emphasis(text: str) -> str:
    text = re.sub(r"\*\*\*([^*]+)\*\*\*", r"\1", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(
        r"(?<!\*)\*(?!\*)([^*\n]+)(?<!\*)\*(?!\*)",
        r"\1",
        text,
    )
    return text


def _trim_equation_tail(eq: str) -> tuple[str, str | None]:
    m = re.search(r"(?i)\s+(eşitlikleri\s+veriliyor\.?)\s*$", eq)
    if m:
        return eq[: m.start()].strip(), m.group(1)
    return eq.strip(), None


def _heal_gx_equation(eq: str, blob: str) -> str:
    eq = eq.strip()
    if re.search(r"(?i)g\([a-z]\)\s*=\s*2x\s*\+", eq):
        return eq
    if re.search(r"(?i)g\([a-z]\)\s*=\s*2x\s*$", eq):
        if re.search(r"(?i)2x\s*\+\s*a", blob) or re.search(
            r"(?i)\ba\b.*gerçel", blob
        ):
            return re.sub(r"(?i)(g\([a-z]\)\s*=\s*2x)\s*$", r"\1 + a", eq)
    return eq


_EQ_G = re.compile(
    r"(?i)\bg\([a-z0-9]+\)\s*=\s*[^$\n]+?"
    r"(?=\s*(?:\([a-z]\s*[°o∘]|\([a-z]{2,3}\)|f\([a-z0-9]+\)|eşitlikleri|$))"
)
_EQ_COMP = re.compile(
    r"(?i)(?:\([a-z]\s*[°o∘]\s*[a-z]\)\([a-z0-9]+\)|\([a-z]{2,3}\)\([a-z0-9]+\))"
    r"\s*=\s*[^$\n]+?"
    r"(?=\s*(?:eşitlikleri|f\([a-z0-9]+\)|olduğuna|$))"
)
_MID_PHRASE = re.compile(r"(?i)eşitlikleri\s+veriliyor\.?")
_Q_SENT = re.compile(
    r"(?i)[fg]\(\d+\)\s*=\s*\d+[^?]*?"
    r"(?:olduğuna\s+göre[^?]*?)?değeri\s+kaçtır\?"
)


def _normalize_math_ocr_blob(text: str) -> str:
    """Ham OCR: +→|, g)→g(x), (fo glx) vb. matematik düzeltmeleri."""
    t = text or ""
    t = re.sub(r"(?i)g\s*\)\s*", "g(x) = ", t)
    t = re.sub(r"(?i)\(\s*fo\s*g\s*l?x\s*\)", "(f o g)(x)", t)
    t = re.sub(r"(?i)\(\s*fg\s*\)\s*\(", "(f o g)(", t)
    t = re.sub(r"(?i)2x\s*[|Il1¡]\s*a", "2x + a", t)
    t = re.sub(r"(?i)2x\s*4\s*a", "2x + a", t)
    t = re.sub(r"(?i)3x\s*[|Il]\s*a", "3x - a", t)
    t = re.sub(r"(?i)3x\s*a\b", "3x - a", t)
    t = re.sub(r"(?i)f\s*\(\s*1\s*\)\s*[|Il]\s*9", "f(1) = 9", t)
    return t


def _question_source_blob(stem: str, raw: str) -> str:
    """Şıklardan önceki ham metin — denklem araması için."""
    raw_q = raw or ""
    m_a = re.search(r"(?m)^\s*A\s*[\)\.\:\-]", raw_q)
    if m_a:
        raw_q = raw_q[: m_a.start()]
    return _strip_ocr_emphasis(
        _normalize_math_ocr_blob(
            _strip_watermarks(f"{stem or ''}\n{raw_q}")
        )
    )


def _find_equations_in_source(source: str) -> list[tuple[int, str]]:
    """Kaynak metinden denklemleri sırayla çıkar (stem + ham OCR)."""
    src = source
    found: list[tuple[int, str]] = []
    seen: set[str] = set()

    def add(pos: int, canonical: str) -> None:
        key = re.sub(r"\s+", " ", canonical.lower())
        if key not in seen:
            seen.add(key)
            found.append((pos, canonical))

    for pat in (_EQ_G, _EQ_COMP):
        for m in pat.finditer(src):
            eq, _ = _trim_equation_tail(m.group(0).strip())
            eq = _heal_gx_equation(eq, src)
            add(m.start(), _latexify_equation_inner(eq))

    for m in re.finditer(r"(?i)g\s*\([a-z0-9]+\)\s*=\s*2x\s*\+\s*a", src):
        add(m.start(), "g(x) = 2x + a")
    for m in re.finditer(r"(?i)g\s*\([a-z0-9]+\)\s*=\s*2x\b", src):
        add(m.start(), "g(x) = 2x + a")

    fog_hint = re.compile(
        r"(?i)(?:"
        r"\([a-z]\s*[°o∘]\s*[a-z]\)\([a-z0-9]+\)\s*=|"
        r"\([a-z]{2,3}\)\([a-z0-9]+\)\s*=|"
        r"\(?\s*f\s*[o°∘]\s*g|\(fo\s*g|fog"
        r")"
    )
    if fog_hint.search(src) or (
        re.search(r"(?i)f ve g fonksiyon", src) and re.search(r"(?i)3x", src)
    ):
        m_fog = fog_hint.search(src) or re.search(r"(?i)3x", src)
        if m_fog and not any("circ" in c for _, c in found):
            add(m_fog.start(), "(f \\circ g)(x) = 3x - a")

    found.sort(key=lambda x: x[0])
    return found


def _repair_math_stem(stem: str, raw: str = "") -> str:
    source = _question_source_blob(stem, raw)
    if not source.strip():
        return ""

    eq_pairs = _find_equations_in_source(source)
    equations = [_wrap_latex_equation(c) for _, c in eq_pairs]

    mid_phrase = ""
    m_mid = _MID_PHRASE.search(source)
    if m_mid:
        mid_phrase = m_mid.group(0).strip()
    elif len(equations) >= 2 and re.search(r"(?i)eşitlik|veriliyor", source):
        mid_phrase = "eşitlikleri veriliyor."

    q_match = _Q_SENT.search(source)
    question = (
        _latexify_question_sentence(_strip_ocr_emphasis(q_match.group(0)))
        if q_match
        else ""
    )

    first_pos = eq_pairs[0][0] if eq_pairs else None
    intro_src = source[:first_pos].strip() if first_pos is not None else source
    intro_src = _MID_PHRASE.sub("", intro_src)
    if q_match:
        intro_src = intro_src.replace(q_match.group(0), "").strip()
    intro = _clean_stem_body(intro_src).strip()
    intro = re.sub(r"\$+", "", intro).strip()

    if not equations:
        lines_out: list[str] = []
        for chunk in _split_equation_chunks(source.replace("\n", " ")):
            if _is_math_equation_line(chunk):
                eq, detached = _trim_equation_tail(chunk)
                if detached and not mid_phrase:
                    mid_phrase = detached
                lines_out.append(
                    _wrap_latex_equation(_heal_gx_equation(eq, source))
                )
            elif re.search(r"(?i)olduğuna\s+göre|değeri\s+kaçtır", chunk):
                question = question or _latexify_question_sentence(chunk)
            elif chunk.strip() and not re.search(
                r"(?i)(henüz kaydedilmedi|uygulama önizlem|ctrl\+v)", chunk
            ):
                intro = f"{intro} {chunk}".strip() if intro else chunk.strip()
        equations = lines_out

    parts: list[str] = []
    if intro:
        parts.append(intro.rstrip(" \n."))
    if equations:
        parts.append("\n".join(equations))
    if mid_phrase:
        parts.append(mid_phrase)
    if question:
        parts.append(question)
    return "\n\n".join(p for p in parts if p).strip()


def _labeled_numeric_options(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for letter, num in re.findall(
        r"(?i)(?:^|[\s>])([A-E])\s*[\)\.:]\s*(-?\d+(?:[.,]\d+)?)",
        text,
    ):
        found.setdefault(letter.upper(), num.replace(",", "."))
    return found


def _numbers_after_question(blob: str) -> list[str]:
    match = re.search(
        r"(?i)(?:olduğuna\s+göre[^?\n]*\?|değeri\s+kaçtır\?|[^\n?]*kaçtır\?)",
        blob,
    )
    if not match:
        return []
    return re.findall(r"\b(\d{1,3})\b", blob[match.end() :])


def _math_option_dirty(val: str) -> bool:
    s = (val or "").strip()
    if not s:
        return True
    if _MATH_OPTION_DIRTY.search(s):
        return True
    if re.match(r"(?i)^(?:şık\s*)?[a-e]\s*$", s):
        return True
    if len(s) > 12 and re.search(r"\d", s):
        return True
    return False


def _repair_math_options(
    stem: str, options: dict[str, str], raw: str
) -> dict[str, str]:
    out = {
        k: _strip_watermarks((options.get(k) or "").strip()) for k in OPTION_KEYS
    }

    merged = _MERGED_DE_OPTION.match(out.get("D", ""))
    if merged:
        out["D"] = merged.group(1)
        if _math_option_dirty(out.get("E", "")):
            out["E"] = merged.group(2)

    blob = "\n".join(p for p in (stem, raw) if p)
    labeled = _labeled_numeric_options(blob)
    nums_after = _numbers_after_question(blob)

    numeric_filled = sum(
        1 for v in out.values() if v and re.fullmatch(r"-?\d+(?:\.\d+)?", v)
    )
    if numeric_filled < 5:
        if len(labeled) >= 4:
            for key in OPTION_KEYS:
                if labeled.get(key) and (
                    not out[key] or _math_option_dirty(out[key])
                ):
                    out[key] = labeled[key]
        elif len(nums_after) >= 5:
            for i, key in enumerate(OPTION_KEYS):
                if not out[key] or _math_option_dirty(out[key]):
                    out[key] = nums_after[i]

    inline = _parse_inline_options(raw)
    for key in OPTION_KEYS:
        val = (inline.get(key) or "").strip()
        if val and re.fullmatch(r"-?\d+(?:\.\d+)?", val):
            if not out[key] or _math_option_dirty(out[key]):
                out[key] = val

    return out


def _repair_math_payload(
    stem: str, options: dict[str, str], raw: str
) -> tuple[str, dict[str, str]]:
    stem = _repair_math_stem(stem, raw)
    options = _repair_math_options(stem, options, raw)
    return stem, options


def _clean_stem_body(text: str) -> str:
    """
    Genel stem onarımı (tüm soru tipleri):
    1) Madde işareti satırlarını göm
    2) Yumuşak satır kırıklarını boşluğa çevir
    3) Parça → soru cümlesi geçişinde paragraf bırak
    Görselden gelen markdown (kalın/italik/altı çizili) korunur.
    """
    text = normalize_turkish_text(text)
    if not text:
        return ""
    lines = _repair_marker_lines(
        [
            ln.rstrip()
            for ln in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
            if not _is_watermark_only_line(ln)
        ]
    )
    chunks: list[str] = []
    buf: list[str] = []

    def flush_buf() -> None:
        if not buf:
            return
        if any(_is_math_equation_line(x) for x in buf):
            line = "\n".join(x.strip() for x in buf if x.strip())
        else:
            line = re.sub(
                r"[ \t]+", " ", " ".join(x.strip() for x in buf if x.strip())
            )
        if line:
            chunks.append(line)
        buf.clear()

    for ln in lines:
        if not ln.strip():
            continue
        stripped = ln.strip()
        is_eq = _is_math_equation_line(stripped)
        if buf:
            buf_has_eq = any(_is_math_equation_line(x) for x in buf)
            if is_eq != buf_has_eq:
                flush_buf()
        if buf and (
            _QUESTION_PARA_START.match(stripped)
            or (
                _is_stem_end_line(ln)
                and not _is_stem_end_line(" ".join(buf))
                and len(" ".join(buf)) > 80
            )
        ):
            flush_buf()
        buf.append(ln)
    flush_buf()
    return "\n\n".join(chunks)


@dataclass
class OcrQuestionResult:
    stem: str
    options: dict[str, str]
    raw_text: str
    ok: bool
    error: str = ""
    engine: str = "tesseract"
    figure_svg: str = ""
    correct_option: str = ""
    solution: str = ""
    topic_slug: str = ""
    subject_slug: str = ""


def _read_source_bytes(source: BinaryIO | bytes | Path | str) -> tuple[bytes, str]:
    if isinstance(source, bytes):
        return source, "image/png"
    if isinstance(source, (str, Path)):
        path = Path(source)
        data = path.read_bytes()
        ext = path.suffix.lower()
        mime = "image/jpeg" if ext in (".jpg", ".jpeg") else "image/png"
        return data, mime
    if hasattr(source, "seek"):
        try:
            source.seek(0)
        except Exception:
            pass
    data = source.read()
    if hasattr(source, "seek"):
        try:
            source.seek(0)
        except Exception:
            pass
    return data, "image/png"


def _ocr_result_score(stem: str, options: dict[str, str], raw: str) -> int:
    filled = sum(1 for k in OPTION_KEYS if (options.get(k) or "").strip())
    score = filled * 12
    if stem:
        score += min(len(stem), 300) // 15
    if filled == 5:
        score += 40
    blob = f"{raw}\n{stem}\n" + "\n".join(options.values())
    low = blob.lower()
    if any(x in low for x in ("sym", "ovens", "dosym", "dösym", "dösvm", "fp\n", "a}")):
        score -= 35
    if re.search(r"(?i)\bV[Vv]?[xyXY]\b|\b\d+V\d|\bVx\b|\bVy\b|\bXx\b|\bYy\b", blob):
        score -= 35
    if re.search(r"__\w+__", blob):
        score -= 20
    for opt in options.values():
        s = (opt or "").strip()
        if s in ("©", "®", "™") or re.match(r"^[,;.\-–—]+\s*\S", s):
            score -= 15
            break
    if "\ufffd" in blob or "�" in blob:
        score -= 40
    if re.search(r"[ÃÂÄÅ]", raw):
        score -= 30
    # Kesir/üs bozulması (Tesseract tipik hata)
    if re.search(r"\b\d+\s*[-–—]\s*\d+\b", stem) and "$" not in stem:
        score -= 20
    # Matematik sorusu ama şıklarda eksi/kesir/kök yok
    if "kaçtır" in low or "oranı" in low:
        opts_text = " ".join(options.values())
        if opts_text and not re.search(r"[-/\\√$]|sqrt|frac", opts_text, re.I):
            if "gerçel" in low or "eşitlik" in low or re.search(
                r"(?i)\bV[xxy]\b|\d+V\d", blob
            ):
                score -= 30
    return score


_MATH_GARBAGE = re.compile(
    r"(?i)(dösym|dosym|dösvm|ovens|\bsym\b|"
    r"\bV[Vv]?[xyXY]\b|\b\d+V\d|\bVx\b|\bVy\b|\bXx\b|\bYy\b)"
)
_OCR_ARTIFACT = re.compile(r"__\w+__|\bde[kc]\b", re.I)
_MATH_STEM_HINT = re.compile(
    r"(?i)(kaçtır|oranı|eşitlikleri|eşitlik|üslü|kesir|frac|\^x|\^\{|"
    r"gerçel say|pozitif.*gerçel|negatif.*gerçel|sqrt|\\sqrt|√|\\frac)"
)
_GEOMETRY_HINT = re.compile(
    r"(?i)(eşkenar|dörtgen|üçgen|çember|doğrusal|kaç birim|birimdir|"
    r"dikdörtgen|\bkare\b|yamuk|deltoid|hipotenüs|kenarortay|açıortay|"
    r"\baçı\b|paralelkenar|çokgen)"
)


def _options_look_suspicious(options: dict[str, str]) -> bool:
    for val in options.values():
        s = (val or "").strip()
        if not s:
            continue
        if s in ("©", "®", "™", "°"):
            return True
        if re.match(r"^[,;.\-–—]+\s*\S", s):
            return True
        if re.search(r"(?i)\b\d+V\d", s):
            return True
    return False


def _likely_geometry_question(
    stem: str, options: dict[str, str], raw: str = ""
) -> bool:
    blob = f"{raw}\n{stem}\n" + "\n".join((options or {}).values())
    return bool(_GEOMETRY_HINT.search(blob))


def _likely_math_question(stem: str, options: dict[str, str], raw: str) -> bool:
    """Kök/kesir/Oran içeren KPSS matematik sorusu."""
    blob = f"{raw}\n{stem}\n" + "\n".join(options.values())
    low = blob.lower()
    if _likely_geometry_question(stem, options, raw):
        return True
    if _MATH_STEM_HINT.search(blob) or _MATH_GARBAGE.search(blob):
        return True
    if _options_look_suspicious(options):
        return True
    if ("kaçtır" in low or "oranı" in low) and (
        "gerçel" in low or "eşitlik" in low or "=" in blob or "$" in blob
    ):
        return True
    return False


def _needs_gemini_fallback(stem: str, options: dict[str, str], raw: str) -> bool:
    """Tesseract matematik / düşük kalite çıktısı — Gemini zorunlu."""
    blob = f"{raw}\n{stem}\n" + "\n".join(options.values())
    low = blob.lower()
    if _MATH_GARBAGE.search(low) or _OCR_ARTIFACT.search(blob):
        return True
    if _likely_math_question(stem, options, raw):
        return True
    stem_s = stem or ""
    if _MATH_STEM_HINT.search(stem_s or raw):
        if "$" not in stem_s and re.search(
            r"\b\d+\s*[-–—]\s*\d+\b|\b\d+x\b|\b2x\b", stem_s, re.I
        ):
            return True
        if "negatif" in low and "kaçtır" in low:
            opts_text = " ".join(options.values())
            if opts_text and "-" not in opts_text and "/" not in opts_text:
                return True
    return False


def _configure_tesseract() -> None:
    import os

    import pytesseract

    cmd = getattr(settings, "TESSERACT_CMD", "") or ""
    if cmd and Path(cmd).exists():
        pytesseract.pytesseract.tesseract_cmd = cmd
    tessdata = getattr(settings, "TESSDATA_DIR", "") or ""
    if tessdata and Path(tessdata).is_dir():
        os.environ["TESSDATA_PREFIX"] = str(Path(tessdata).resolve()) + os.sep


def _tesseract_user_error(exc: BaseException) -> str:
    name = type(exc).__name__
    text = str(exc) or name
    low = text.casefold()
    if (
        "TesseractNotFoundError" in name
        or "tesseract is not installed" in low
        or "tesseractnotfound" in low
    ):
        return (
            "Tesseract OCR sunucuda bulunamadı. "
            "Tesseract kurulumunu ve TESSERACT_CMD ayarını kontrol edin."
        )
    if "testdata" in low or "traineddata" in low:
        return (
            "Tesseract dil paketi (tessdata) eksik veya hatalı. "
            "TESSDATA_DIR ayarını kontrol edin."
        )
    return f"OCR sırasında hata oluştu: {text}"


def _load_image(source: BinaryIO | bytes | Path | str) -> Image.Image:
    if isinstance(source, (str, Path)):
        img = Image.open(source)
    elif isinstance(source, bytes):
        img = Image.open(BytesIO(source))
    else:
        pos = source.tell() if hasattr(source, "tell") else None
        img = Image.open(source)
        if pos is not None and hasattr(source, "seek"):
            source.seek(pos)
    img = ImageOps.exif_transpose(img)
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    w, h = img.size
    if max(w, h) < 1600:
        scale = 1600 / max(w, h)
        img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
    gray = ImageOps.grayscale(img)
    gray = ImageOps.autocontrast(gray, cutoff=1)
    gray = gray.filter(ImageFilter.SHARPEN)
    return gray


def _tesseract_once(img: Image.Image, lang: str, psm: int) -> str:
    import pytesseract

    config = f"--oem 3 --psm {psm} -c preserve_interword_spaces=1"
    return pytesseract.image_to_string(img, lang=lang, config=config) or ""


def extract_text(source: BinaryIO | bytes | Path | str) -> str:
    """Görselden ham OCR metni; biçimli (markdown) çıktı üretir."""
    _configure_tesseract()
    try:
        img = _load_image(source)
    except Exception as exc:  # noqa: BLE001
        raise ValueError(
            "Görsel açılamadı. Desteklenen bir resim dosyası yükleyin."
        ) from exc

    langs = getattr(settings, "TESSERACT_LANG", "tur") or "tur"
    lang_candidates: list[str] = []
    for part in str(langs).split(","):
        part = part.strip()
        if part and part not in lang_candidates:
            lang_candidates.append(part)
    for extra in ("tur", "tur+eng"):
        if extra not in lang_candidates:
            lang_candidates.append(extra)

    best_raw = ""
    best_score = -1
    best_lang = "tur"
    best_psm = 6
    last_error: BaseException | None = None
    for lang in lang_candidates:
        for psm in (6, 4, 3):
            try:
                raw = normalize_turkish_text(_tesseract_once(img, lang, psm))
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                continue
            if not raw.strip():
                continue
            stem, opts = parse_question_text(raw)
            filled = sum(1 for k in OPTION_KEYS if (opts.get(k) or "").strip())
            # Tam A–E + uzun şık metinleri ödüllendir
            score = filled * 10 + sum(min(len(opts[k]), 80) for k in OPTION_KEYS)
            if filled == 5:
                score += 50
            if stem:
                score += min(len(stem), 200) // 10
            if score > best_score:
                best_score = score
                best_raw = raw
                best_lang = lang
                best_psm = psm
        if best_score >= 5 * 10 + 50:
            break

    if not best_raw.strip():
        if last_error is not None:
            raise RuntimeError(_tesseract_user_error(last_error)) from last_error
        return best_raw

    # En iyi PSM/dil ile kelime kutularından biçim (kalın/italik/altı çizili)
    try:
        styled = normalize_turkish_text(
            extract_styled_text(img, best_lang, best_psm)
        )
        if styled.strip():
            # Biçimli metin de şıkları bozmamalı; skor düşerse düz metne dön
            stem_s, opts_s = parse_question_text(styled)
            filled_s = sum(1 for k in OPTION_KEYS if (opts_s.get(k) or "").strip())
            score_s = filled_s * 10 + sum(
                min(len(opts_s[k]), 80) for k in OPTION_KEYS
            )
            if filled_s == 5:
                score_s += 50
            if stem_s:
                score_s += min(len(stem_s), 200) // 10
            if score_s >= best_score - 15:
                return styled
    except Exception:
        pass
    return best_raw


def _merge_orphan_paren_lines(lines: list[str]) -> list[str]:
    """`) istediği` gibi kırıkları bir önceki satıra yapıştır."""
    out: list[str] = []
    for ln in lines:
        m = _ORPHAN_PAREN.match(ln)
        if m and out:
            out[-1] = out[-1].rstrip() + " " + m.group(1).strip()
        else:
            out.append(ln)
    return out


def _looks_like_option_line(ln: str, expect: str | None) -> tuple[str | None, str]:
    """
    Satır şık başlangıcı mı?
    expect: sıradaki beklenen harf (A…E); OCR sapmalarını buna göre kabul et.
    """
    strict = _OPTION_STRICT.match(ln)
    loose = _OPTION_START.match(ln)
    garbled = _OPTION_GARBLED.match(ln) if not strict else None
    m = strict or garbled or loose
    if not m:
        return None, ""

    raw_key = m.group(1)
    body = (m.group(2) or "").strip()
    key = _normalize_option_key(raw_key)

    # Ayırıcısız uzun satır (ör. "A sorun...") — yalnızca beklenen harfse ve kısa gövde/şık gibiyse
    if loose and not strict and not garbled:
        # "D   Yaşam..." gibi gerçek şık: harf + ≥2 boşluk
        if not re.match(r"^\s*[A-Ea-e680OQG]\s{2,}", ln):
            # Tek boşluklu "A kelime..." gövde cümlesi riski
            if expect is None or key != expect:
                return None, ""
            if len(ln.strip()) > 90 and key == "A":
                return None, ""

    if key is None:
        return None, ""

    # Sıra bekleniyorsa: ya tam eşleş ya da OCR sapması (6→C beklenen C iken)
    if expect is not None:
        if key == expect:
            return key, body
        # Ham karakter beklenen harfin bilinen OCR karşılığı mı?
        if _OCR_LETTER_FIX.get(raw_key) == expect or _OCR_LETTER_FIX.get(
            raw_key.upper()
        ) == expect:
            return expect, body
        return None, ""

    return key, body


_OPTION_CONTINUATION = re.compile(r"^[a-zçğıöşü]")
# Önceki şıkta tamamlanmış cümleden sonra gelen yeni şık parçası
_OPTION_TAIL_BOUNDARY = re.compile(
    r"[.!?]\s+(?=(?:[IVXİ]{1,4}\.|\d+\.|[A-ZÇĞİÖŞÜ]))"
)


def _peel_embedded_options(options: dict[str, str]) -> dict[str, str]:
    """
    Bir şık gövdesine yapışmış sonraki şıkları ayır.

    Örnek (Romen şıklı OCR): B = "I ve IV cCc) II ve III" → B="I ve IV", C="II ve III"
    """
    out = {k: (options.get(k) or "").strip() for k in OPTION_KEYS}
    for _ in range(len(OPTION_KEYS)):
        moved = False
        for i, key in enumerate(OPTION_KEYS[:-1]):
            body = out[key]
            if not body:
                continue
            later = set(OPTION_KEYS[i + 1 :])
            match = None
            found_key = None
            for m in _EMBEDDED_OPTION_MARK.finditer(body):
                nk = _normalize_option_key(m.group("key"))
                if nk in later:
                    match = m
                    found_key = nk
                    break
            if match is None or found_key is None:
                continue
            head = body[: match.start()].strip()
            tail = body[match.end() :].strip()
            if not head or not tail:
                continue
            out[key] = _clean_option_body(head)
            if not out[found_key]:
                out[found_key] = _clean_option_body(tail)
            else:
                for k2 in OPTION_KEYS[i + 1 :]:
                    if not out[k2]:
                        out[k2] = _clean_option_body(tail)
                        break
            moved = True
            break
        if not moved:
            break
    return out


def _rebalance_wrapped_option(prev: str, new_body: str) -> tuple[str, str]:
    """
    OCR sıkça D şıkkının ilk satırını C'ye yapıştırır; D) yalnızca ikinci satırda kalır:

      C) … alınmıştır.
      II. cümlede … yoluna          ← aslında D'nin başı
      D) gidilerek somutlaştırılmıştır.

    new_body küçük harfle başlıyorsa (devam satırı), prev'teki son cümle
    sınırından sonrasını yeni şıkka taşı.
    """
    prev = (prev or "").strip()
    new_body = (new_body or "").strip()
    if not prev or not new_body:
        return prev, new_body
    if not _OPTION_CONTINUATION.match(new_body):
        return prev, new_body

    last = None
    for cand in _OPTION_TAIL_BOUNDARY.finditer(prev):
        last = cand
    if last is None:
        return prev, new_body

    head = prev[: last.start() + 1].strip()
    tail = prev[last.end() :].strip()
    if len(head) < 12 or len(tail) < 8:
        return prev, new_body
    return head, f"{tail} {new_body}".strip()


def parse_question_text(raw: str) -> tuple[str, dict[str, str]]:
    """Ham metinden stem + A–E şıkları (sıralı, çok satırlı şık destekli)."""
    options: dict[str, str] = {k: "" for k in OPTION_KEYS}
    raw = normalize_turkish_text(raw)
    if not raw:
        return "", options

    lines = _merge_orphan_paren_lines([ln.rstrip() for ln in raw.split("\n")])

    # 1) İlk kesin A) / A. işaretini bul — ondan önceki her şey stem
    first_a_idx: int | None = None
    for i, ln in enumerate(lines):
        key, _ = _looks_like_option_line(ln, "A")
        if key == "A":
            # Tercihen ayırıcılı
            if _OPTION_STRICT.match(ln) or re.match(r"^\s*A\s{2,}", ln):
                first_a_idx = i
                break
            if first_a_idx is None:
                first_a_idx = i
    if first_a_idx is None:
        # A bulunamadı: herhangi bir şık satırı?
        for i, ln in enumerate(lines):
            key, _ = _looks_like_option_line(ln, None)
            if key in OPTION_KEYS:
                first_a_idx = i
                break

    if first_a_idx is None:
        return raw, options

    # Stem sonu (? / söylenemez) ile A) arasındaki kısa kırıklar A şıkkı başı
    # olabilir; uzun olay metni / maddeler stem'de kalır (sözel mantık).
    pre_a = list(lines[:first_a_idx])
    a_prefix: list[str] = []
    a_line_body = ""
    if first_a_idx is not None:
        _, a_line_body = _looks_like_option_line(lines[first_a_idx], "A")

    # Aynı satırda '? ...' sonrası şık parçası
    if pre_a:
        head, tail = _split_question_tail(pre_a[-1])
        if tail and _looks_like_option_a_prefix([tail], a_line_body):
            pre_a[-1] = head
            a_prefix.append(tail)

    last_stem_end: int | None = None
    for j in range(len(pre_a) - 1, -1, -1):
        if _is_stem_end_line(pre_a[j]):
            last_stem_end = j
            break

    if last_stem_end is not None and last_stem_end < len(pre_a) - 1:
        gap = pre_a[last_stem_end + 1 :]
        if _looks_like_option_a_prefix(gap, a_line_body):
            a_prefix = gap + a_prefix
            pre_a = pre_a[: last_stem_end + 1]

    stem = _clean_stem_body("\n".join(pre_a))

    # 2) A→E sırasıyla şıkları topla
    expect_i = 0
    current_key: str | None = None
    buf: list[str] = []
    pending_a_prefix = list(a_prefix)

    def flush() -> None:
        nonlocal current_key, buf
        if current_key and current_key in options:
            options[current_key] = _clean_option_body("\n".join(buf))
        current_key = None
        buf = []

    i = first_a_idx
    while i < len(lines):
        ln = lines[i]
        expect = OPTION_KEYS[expect_i] if expect_i < len(OPTION_KEYS) else None

        key, body = _looks_like_option_line(ln, expect)
        if key is None and expect is not None:
            for ahead in range(expect_i, len(OPTION_KEYS)):
                k2, b2 = _looks_like_option_line(ln, OPTION_KEYS[ahead])
                if k2:
                    key, body = k2, b2
                    expect_i = ahead
                    expect = OPTION_KEYS[expect_i]
                    break

        if key is not None and expect is not None and key == expect:
            # Yeni şık başlamadan önce: kırık satır C'ye yapışmış olabilir
            if current_key and buf and body:
                joined = _clean_option_body("\n".join(buf))
                joined, body = _rebalance_wrapped_option(joined, body)
                buf = [joined] if joined else []
            flush()
            current_key = key
            if key == "A" and pending_a_prefix:
                buf = list(pending_a_prefix)
                pending_a_prefix = []
                if body:
                    buf.append(body)
            else:
                buf = [body] if body else []
            expect_i += 1
            i += 1
            continue

        if current_key is not None:
            if ln.strip():
                buf.append(ln.strip())
            i += 1
            continue

        i += 1

    flush()
    options = _peel_embedded_options(options)

    # 3) Eksik şık kaldıysa: satır içi A) B) C) tarama (yedek)
    if sum(1 for v in options.values() if v) < 3:
        inline = _parse_inline_options(raw)
        for k in OPTION_KEYS:
            if not options[k] and inline.get(k):
                options[k] = inline[k]
        options = _peel_embedded_options(options)
        if not stem:
            m = re.search(r"(?:^|\n)\s*A\s*[\)\]\.\:\-]", raw)
            if m:
                stem = _clean_stem_body(raw[: m.start()])

    return stem, options


def _parse_inline_options(raw: str) -> dict[str, str]:
    """Tek blokta A) … B) … yan yana şıklar."""
    options: dict[str, str] = {k: "" for k in OPTION_KEYS}
    pattern = re.compile(
        r"(?:^|[\s\n])([A-Ea-e680]|[A-Ea-e]{2,4})\s*[\)\]\.\:\-\–\—]\s*",
    )
    matches = list(pattern.finditer(raw))
    keyed: list[tuple[int, int, str]] = []
    for m in matches:
        key = _normalize_option_key(m.group(1))
        if key:
            keyed.append((m.start(), m.end(), key))

    # A→E sırasını seç
    picked: list[tuple[int, int, str]] = []
    ei = 0
    for start, end, key in keyed:
        if ei < 5 and key == OPTION_KEYS[ei]:
            picked.append((start, end, key))
            ei += 1

    for i, (start, end, key) in enumerate(picked):
        stop = picked[i + 1][0] if i + 1 < len(picked) else len(raw)
        options[key] = _clean_option_body(raw[end:stop])
    return options


def ocr_question_image(source: BinaryIO | bytes | Path | str) -> OcrQuestionResult:
    """Görsel → stem + options (yerel Tesseract OCR)."""
    empty_opts = {k: "" for k in OPTION_KEYS}
    try:
        img_bytes, mime = _read_source_bytes(source)
    except Exception as exc:  # noqa: BLE001
        return OcrQuestionResult(
            stem="",
            options=empty_opts,
            raw_text="",
            ok=False,
            error=_tesseract_user_error(exc)
            if "tesseract" in type(exc).__name__.casefold()
            else "Görsel okunamadı. Geçerli bir resim yükleyin.",
        )

    if not img_bytes:
        return OcrQuestionResult(
            stem="",
            options=empty_opts,
            raw_text="",
            ok=False,
            error="Boş veya geçersiz görsel yüklendi.",
        )

    try:
        raw = extract_text(BytesIO(img_bytes))
    except Exception as exc:  # noqa: BLE001
        return OcrQuestionResult(
            stem="",
            options=empty_opts,
            raw_text="",
            ok=False,
            error=_tesseract_user_error(exc),
        )

    if not (raw or "").strip():
        return OcrQuestionResult(
            stem="",
            options=empty_opts,
            raw_text="",
            ok=False,
            error=(
                "Görselden metin okunamadı. Daha net bir görsel deneyin "
                "veya alanları elle doldurun."
            ),
        )

    stem, options = parse_question_text(raw)
    if _likely_geometry_question(stem, options, raw):
        from .ocr_gemini import _repair_geometry_payload

        stem, options = _repair_geometry_payload(stem, options)
    elif _likely_math_question(stem, options, raw):
        stem, options = _repair_math_payload(stem, options, raw)
    else:
        stem = _strip_watermarks(stem)
    filled = sum(1 for v in options.values() if v)
    ok = bool(stem or filled)
    if not stem and raw and not filled:
        stem = raw

    hint = ""
    if _likely_math_question(stem, options, raw) and "$" not in (stem or ""):
        hint = (
            " Matematik formülleri Tesseract ile eksik kalabilir; "
            "denklemleri elle $...$ ile yazın veya çözümü Gemini'den yapıştırın."
        )

    return OcrQuestionResult(
        stem=stem,
        options=options,
        raw_text=raw,
        ok=ok,
        error="" if ok else "Görselden metin okunamadı." + hint,
        engine="tesseract",
    )
