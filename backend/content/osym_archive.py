"""ÖSYM Çıkmış Sorular arşiv kataloğu ve panel istatistikleri."""

from __future__ import annotations

import re
from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable, Iterator

from django.db.models import Count

from .models import Question
from .osym_cikmis import normalize_osym_cikmis_label

# Etiket biçimi: «2025 KPSS Lisans · Genel Yetenek - Genel Kültür»
# İsteğe bağlı soru numarası: «… · Soru 12»
LABEL_SEPARATOR = " · "
SORU_SUFFIX_RE = re.compile(r"\s·\s*soru\s+\d+\s*$", re.IGNORECASE)
YEAR_PREFIX_RE = re.compile(r"^(\d{4})\s+(.+)$")


@dataclass(frozen=True)
class OsymArchiveSlot:
    """Beklenen bir resmi sınav oturumu."""

    family: str
    exam_name: str
    session_key: str
    session_name: str
    expected_count: int

    def canonical_label(self, year: int) -> str:
        return f"{year} {self.exam_name}{LABEL_SEPARATOR}{self.session_name}"


@dataclass
class OsymArchiveSlotStats:
    slot: OsymArchiveSlot
    year: int
    canonical_label: str
    active_count: int
    total_count: int
    unpublished_count: int

    @property
    def expected_count(self) -> int:
        return self.slot.expected_count

    @property
    def status(self) -> str:
        if self.active_count <= 0:
            return "missing"
        if self.active_count >= self.expected_count:
            return "complete"
        return "partial"

    @property
    def progress_pct(self) -> int:
        if self.expected_count <= 0:
            return 0
        return min(100, round(100 * self.active_count / self.expected_count))


@dataclass
class OsymArchiveYearGroup:
    year: int
    exams: list[OsymArchiveExamGroup]


@dataclass
class OsymArchiveExamGroup:
    family: str
    exam_name: str
    sessions: list[OsymArchiveSlotStats]


@dataclass
class OsymArchiveExtraGroup:
    archive_key: str
    year: int | None
    exam_hint: str
    active_count: int
    total_count: int


# Oturum şablonları — yıl döngüsüyle katalog üretilir.
_EXAM_TEMPLATES: tuple[dict, ...] = (
    {
        "family": "KPSS",
        "exam_name": "KPSS Lisans",
        "sessions": (("gygk", "Genel Yetenek - Genel Kültür", 120),),
    },
    {
        "family": "KPSS",
        "exam_name": "KPSS Önlisans",
        "sessions": (("gygk", "Genel Yetenek - Genel Kültür", 120),),
    },
    {
        "family": "KPSS",
        "exam_name": "KPSS Ortaöğretim",
        "sessions": (("gygk", "Genel Yetenek - Genel Kültür", 120),),
    },
    {
        "family": "AGS",
        "exam_name": "AGS",
        "sessions": (("ags", "MEB Akademi Giriş Sınavı", 80),),
    },
    {
        "family": "ALES",
        "exam_name": "ALES",
        "sessions": (("ales", "ALES", 100),),
    },
    {
        "family": "YKS",
        "exam_name": "TYT",
        "sessions": (("tyt", "Temel Yeterlilik Testi", 120),),
    },
    {
        "family": "YKS",
        "exam_name": "AYT Sayısal",
        "sessions": (("ayt_say", "Alan Yeterlilik Testi", 80),),
    },
    {
        "family": "YKS",
        "exam_name": "AYT Sözel",
        "sessions": (("ayt_soz", "Alan Yeterlilik Testi", 80),),
    },
    {
        "family": "YKS",
        "exam_name": "AYT Eşit Ağırlık",
        "sessions": (("ayt_ea", "Alan Yeterlilik Testi", 80),),
    },
    {
        "family": "YKS",
        "exam_name": "AYT Dil",
        "sessions": (("ayt_dil", "Yabancı Dil Testi", 80),),
    },
    {
        "family": "DGS",
        "exam_name": "DGS",
        "sessions": (("dgs", "DGS", 120),),
    },
)

DEFAULT_YEARS = range(2019, 2027)


def archive_key_from_label(raw: str) -> str:
    """Soru numarası sonekini atıp arşiv anahtarını döndürür."""
    normalized = normalize_osym_cikmis_label(raw)
    if not normalized:
        return ""
    return normalize_osym_cikmis_label(SORU_SUFFIX_RE.sub("", normalized))


def parse_archive_key(key: str) -> tuple[int | None, str]:
    """«2025 KPSS Lisans · GYGK» → (2025, kalan parça)."""
    normalized = archive_key_from_label(key)
    if not normalized:
        return None, ""
    match = YEAR_PREFIX_RE.match(normalized)
    if not match:
        return None, normalized
    return int(match.group(1)), match.group(2).strip()


def iter_catalog_slots(*, years: Iterable[int] | None = None) -> Iterator[tuple[int, OsymArchiveSlot]]:
    year_list = list(years or DEFAULT_YEARS)
    for year in sorted(year_list, reverse=True):
        for template in _EXAM_TEMPLATES:
            for session_key, session_name, expected in template["sessions"]:
                yield year, OsymArchiveSlot(
                    family=template["family"],
                    exam_name=template["exam_name"],
                    session_key=session_key,
                    session_name=session_name,
                    expected_count=expected,
                )


def _question_counts_by_key() -> dict[str, dict[str, int | str]]:
    """Arşiv anahtarı (casefold) → {active, total, unpublished, display_label}."""
    rows = (
        Question.objects.filter(osym_sordu=True)
        .exclude(osym_cikmis_adi="")
        .values("osym_cikmis_adi", "is_published")
        .annotate(c=Count("id"))
    )
    merged: dict[str, dict[str, int | str]] = defaultdict(
        lambda: {"active": 0, "total": 0, "unpublished": 0, "display_label": ""}
    )
    for row in rows:
        key = archive_key_from_label(row["osym_cikmis_adi"])
        if not key:
            continue
        bucket = merged[key.casefold()]
        if not bucket["display_label"]:
            bucket["display_label"] = key
        bucket["total"] = int(bucket["total"]) + row["c"]
        if row["is_published"]:
            bucket["active"] = int(bucket["active"]) + row["c"]
        else:
            bucket["unpublished"] = int(bucket["unpublished"]) + row["c"]
    return merged


def _slot_stats(
    *,
    year: int,
    slot: OsymArchiveSlot,
    counts: dict[str, dict[str, int | str]],
) -> OsymArchiveSlotStats:
    label = slot.canonical_label(year)
    bucket = counts.get(label.casefold(), {"active": 0, "total": 0, "unpublished": 0})
    return OsymArchiveSlotStats(
        slot=slot,
        year=year,
        canonical_label=label,
        active_count=int(bucket.get("active", 0)),
        total_count=int(bucket.get("total", 0)),
        unpublished_count=int(bucket.get("unpublished", 0)),
    )


def build_archive_tree(
    *,
    years: Iterable[int] | None = None,
    family_filter: str = "",
    year_filter: int | None = None,
) -> list[OsymArchiveYearGroup]:
    counts = _question_counts_by_key()
    by_year: dict[int, dict[str, OsymArchiveExamGroup]] = defaultdict(dict)
    for year, slot in iter_catalog_slots(years=years):
        if year_filter is not None and year != year_filter:
            continue
        if family_filter and slot.family.casefold() != family_filter.casefold():
            continue
        stats = _slot_stats(year=year, slot=slot, counts=counts)
        exam_map = by_year[year]
        if slot.exam_name not in exam_map:
            exam_map[slot.exam_name] = OsymArchiveExamGroup(
                family=slot.family,
                exam_name=slot.exam_name,
                sessions=[],
            )
        exam_map[slot.exam_name].sessions.append(stats)

    tree: list[OsymArchiveYearGroup] = []
    for year in sorted(by_year.keys(), reverse=True):
        exams = sorted(by_year[year].values(), key=lambda e: (e.family, e.exam_name))
        for exam in exams:
            exam.sessions.sort(key=lambda s: s.slot.session_name)
        tree.append(OsymArchiveYearGroup(year=year, exams=exams))
    return tree


def build_extra_groups(*, years: Iterable[int] | None = None) -> list[OsymArchiveExtraGroup]:
    """Katalog dışı veya farklı yazılmış etiket grupları."""
    counts = _question_counts_by_key()
    catalog_keys = {
        slot.canonical_label(year).casefold()
        for year, slot in iter_catalog_slots(years=years)
    }
    extras: list[OsymArchiveExtraGroup] = []
    for key_fold, bucket in counts.items():
        if key_fold in catalog_keys:
            continue
        display_key = str(bucket.get("display_label") or key_fold)
        year, rest = parse_archive_key(display_key)
        extras.append(
            OsymArchiveExtraGroup(
                archive_key=display_key,
                year=year,
                exam_hint=rest,
                active_count=int(bucket.get("active", 0)),
                total_count=int(bucket.get("total", 0)),
            )
        )
    extras.sort(key=lambda g: (g.year or 0, g.archive_key), reverse=True)
    return extras


def build_archive_summary(*, years: Iterable[int] | None = None) -> dict[str, int]:
    counts = _question_counts_by_key()
    all_slots = list(iter_catalog_slots(years=years))
    complete = partial = missing = 0
    loaded_active = 0
    for year, slot in all_slots:
        label = slot.canonical_label(year)
        active = int(counts.get(label.casefold(), {}).get("active", 0))
        loaded_active += active
        if active <= 0:
            missing += 1
        elif active >= slot.expected_count:
            complete += 1
        else:
            partial += 1

    untagged = Question.objects.filter(osym_sordu=True, osym_cikmis_adi="").count()
    tagged_osym = Question.objects.filter(osym_sordu=True).exclude(osym_cikmis_adi="").count()
    active_osym = Question.objects.filter(osym_sordu=True, is_published=True).count()

    return {
        "catalog_slots": len(all_slots),
        "complete_slots": complete,
        "partial_slots": partial,
        "missing_slots": missing,
        "loaded_in_catalog": loaded_active,
        "untagged_osym": untagged,
        "tagged_osym": tagged_osym,
        "active_osym": active_osym,
        "extra_groups": len(build_extra_groups(years=years)),
    }


def questions_for_archive_key(
    archive_key: str,
    *,
    published_only: bool = False,
) -> list[Question]:
    """Verilen arşiv anahtarına düşen sorular."""
    target = archive_key_from_label(archive_key).casefold()
    if not target:
        return []
    qs = Question.objects.filter(osym_sordu=True).select_related("topic", "topic__subject")
    if published_only:
        qs = qs.filter(is_published=True)
    matched: list[Question] = []
    for q in qs:
        if archive_key_from_label(q.osym_cikmis_adi).casefold() == target:
            matched.append(q)
    matched.sort(key=lambda q: (q.topic.subject.name, q.topic.name, q.public_id))
    return matched


def archive_families() -> list[str]:
    seen: list[str] = []
    for template in _EXAM_TEMPLATES:
        if template["family"] not in seen:
            seen.append(template["family"])
    return seen


def archive_years(*, years: Iterable[int] | None = None) -> list[int]:
    return sorted(list(years or DEFAULT_YEARS), reverse=True)
