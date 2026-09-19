"""Özel test etiketleri — keyword/regex önerisi + bayrak uygulama."""

from __future__ import annotations

import re
import unicodedata
from typing import Iterable

TAG_KRONOLOJI = "tag_kronoloji"
TAG_PADISAH = "tag_padisah_antlasma"
TAG_CELDIRICI = "tag_celdirici"

ALL_SPECIAL_TAGS = (TAG_KRONOLOJI, TAG_PADISAH, TAG_CELDIRICI)

_KRONOLOJI_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE | re.DOTALL)
    for p in (
        r"tarih\s*s[ıi]ras[ıi]na\s*g[öo]re",
        r"kronoloj",
        r"hangisi\s+daha\s+[öo]nce",
        r"hangisi\s+[öo]nce\s+ger[çc]ekle[şs]",
        r"hangi\s+olay\s.{0,40}[öo]nce",
        r"[öo]nce\s*.{0,30}sonra",
        r"a[şs]a[ğg][ıi]dakilerden\s+hangisi\s.{0,40}[öo]nce",
        r"olaylar[ıi]n\s.{0,20}s[ıi]ralamas[ıi]",
        r"zaman\s+s[ıi]ras[ıi]",
        r"kronolojik\s+s[ıi]ra",
    )
)

_PADISAH_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE | re.DOTALL)
    for p in (
        r"padi[şs]ah",
        r"antla[şs]ma",
        r"\bsulh\b",
        r"\bferman\b",
        r"osmanl[ıi]\s.{0,20}padi[şs]ah",
        r"fatih\s+sultan\s+mehmed",
        r"kanuni\s+sultan\s+s[üu]leyman",
        r"yalova\s+antla[şs]mas[ıi]",
        r"karlof[çc]a",
        r"pasarof[çc]a",
        r"k[üu][çc][üu]k\s+kaynarca",
        r"ayasofya\s+ferman",
        r"halife",
        r"tahta\s+[çc][ıi]k[ıi][şs]",
        r"c[üu]lus",
    )
)


def _normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text or "")
    return " ".join(text.split())


def suggest_tags(stem: str, options_text: str = "") -> set[str]:
    """Metin kalıplarından önerilen özel test etiketleri."""
    blob = _normalize(f"{stem}\n{options_text}")
    found: set[str] = set()
    for pat in _KRONOLOJI_PATTERNS:
        if pat.search(blob):
            found.add(TAG_KRONOLOJI)
            break
    for pat in _PADISAH_PATTERNS:
        if pat.search(blob):
            found.add(TAG_PADISAH)
            break
    return found


def options_blob(question) -> str:
    parts = [
        getattr(question, "option_a", "") or "",
        getattr(question, "option_b", "") or "",
        getattr(question, "option_c", "") or "",
        getattr(question, "option_d", "") or "",
        getattr(question, "option_e", "") or "",
    ]
    return "\n".join(parts)


def apply_auto_tags(question, *, only_raise: bool = True) -> set[str]:
    """
    Keyword eşleşen bayrakları True yapar.
    only_raise=True iken mevcut True değerleri False yapılmaz.
    Dönen küme: bu çağrıda True yapılan etiketler.
    """
    suggested = suggest_tags(
        getattr(question, "stem", "") or "",
        options_blob(question),
    )
    raised: set[str] = set()
    for tag in suggested:
        if not hasattr(question, tag):
            continue
        current = bool(getattr(question, tag))
        if only_raise and current:
            continue
        if not current:
            setattr(question, tag, True)
            raised.add(tag)
    return raised


def apply_auto_tags_to_queryset(qs: Iterable, *, save: bool = True) -> int:
    """Toplu retag; güncellenen soru sayısı."""
    updated = 0
    for q in qs:
        raised = apply_auto_tags(q, only_raise=True)
        if raised:
            updated += 1
            if save:
                q.save(
                    update_fields=sorted(raised) + ["updated_at"]
                    if hasattr(q, "updated_at")
                    else sorted(raised)
                )
    return updated
