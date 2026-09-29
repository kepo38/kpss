"""ÖSYM Çıkmış Sorular arşiv kataloğu ve panel istatistikleri."""

from __future__ import annotations

import re
from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable, Iterator

from django.db.models import Count

from .models import Question
from .osym_cikmis import normalize_osym_cikmis_label

# Etiket biçimi: «2025 KPSS Lisans», «2026-HMGS/1»
# İsteğe bağlı soru numarası: «… · Soru 12»
LABEL_SEPARATOR = " · "
SORU_SUFFIX_RE = re.compile(r"\s·\s*soru\s+\d+\s*$", re.IGNORECASE)
YEAR_PREFIX_RE = re.compile(r"^(\d{4})(?:\s+|-)(.+)$")
# Eski panel etiketleri: «2026 AYT Eşit Ağırlık · Alan Yeterlilik Testi» → «2026 AYT»
_AYT_LEGACY_EXAM_RE = re.compile(
    r"^(\d{4})\s+AYT\s+(?:Sayısal|Sözel|Eşit\s+Ağırlık|Dil)"
    r"(?:\s·\s*(?:Alan Yeterlilik Testi|Yabancı Dil Testi|ayt(?:_(?:say|soz|ea|dil))?))?$",
    re.IGNORECASE,
)
# Eski adli/idari etiketleri → «2026-HMGS/1»
_HMGS_LEGACY_EXAM_RE = re.compile(
    r"^(\d{4})\s+(?:Adli|İdari|Idari)\s+Yarg[ıi]\s+Hakimli[gğ]i"
    r"(?:\s·\s*Yaz[ıi]l[ıi]\s+S[ıi]nav)?$",
    re.IGNORECASE,
)
_HMGS_LOOSE_RE = re.compile(
    r"^(\d{4})[\s\-]+HMGS(?:[\s·/]+(\d+))?$",
    re.IGNORECASE,
)
# Eski / kısa İYÖS etiketleri → «2024-İYÖS/1»
_IYOS_LOOSE_RE = re.compile(
    r"^(\d{4})[\s\-]+(?:İ|I|i)Y[ÖOöo]S(?:[\s·/]+(\d+))?$",
    re.IGNORECASE,
)
# Eski KPSS oturum soneki: «2026 KPSS Lisans · Genel Yetenek - Genel Kültür»
_KPSS_GYGK_LEGACY_RE = re.compile(
    r"^(\d{4}\s+KPSS\s+(?:Lisans|Önlisans|On\s*Lisans|Ortaöğretim|Ortaogretim))"
    r"(?:\s·\s*(?:Genel Yetenek\s*-\s*Genel Kültür|GYGK))$",
    re.IGNORECASE,
)
# Eski AGS oturum soneki: «2025 AGS · MEB Akademi Giriş Sınavı» → «2025 AGS»
_AGS_LEGACY_SESSION_RE = re.compile(
    r"^(\d{4})\s+AGS(?:\s·\s*MEB\s+Akademi\s+Giri[sş]\s+S[ıi]nav[ıi])?$",
    re.IGNORECASE,
)
# Branşlı / ASCII ÖABT: «2025 TARİH ÖABT», «2024 ÖABT Turkce», «2025 OABT» → «YYYY ÖABT»
_OABT_LOOSE_RE = re.compile(
    r"^(\d{4})\b(?:(?!\d{4}).)*\b(?:Ö|O|ö|o)ABT\b",
    re.IGNORECASE,
)
# Branşlı AGS (nadir): «2025 AGS Alan» → «2025 AGS»
_AGS_BRANCH_RE = re.compile(
    r"^(\d{4})\b(?:(?!\d{4}).)*\bAGS\b",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class OsymArchiveSlot:
    """Beklenen bir resmi sınav oturumu."""

    family: str
    exam_name: str
    session_key: str
    session_name: str
    expected_count: int
    label_template: str = ""

    def canonical_label(self, year: int) -> str:
        tpl = (self.label_template or "").strip()
        if tpl:
            return tpl.format(
                year=year,
                exam_name=self.exam_name,
                session_key=self.session_key,
                session_name=self.session_name or "",
            )
        primary = f"{year} {self.exam_name}"
        session = (self.session_name or "").strip()
        if not session or _session_suffix_redundant(self.exam_name, session):
            return primary
        return f"{primary}{LABEL_SEPARATOR}{session}"


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
        "sessions": (("gygk", "", 120),),
    },
    {
        "family": "KPSS",
        "exam_name": "KPSS Önlisans",
        "sessions": (("gygk", "", 120),),
    },
    {
        "family": "KPSS",
        "exam_name": "KPSS Ortaöğretim",
        "sessions": (("gygk", "", 120),),
    },
    {
        "family": "KPSS",
        "exam_name": "KPSS A Grubu",
        "sessions": (("a", "", 80),),
        "short_aliases": (
            "kpss a",
            "a grubu",
            "kpss a grubu",
            "a",
        ),
    },
    {
        "family": "MEB Akademi",
        "exam_name": "AGS",
        "sessions": (("ags", "", 80),),
        "short_aliases": ("ags",),
    },
    {
        "family": "MEB Akademi",
        "exam_name": "ÖABT",
        "sessions": (("oabt", "", 80),),
        "short_aliases": (
            "öabt",
            "oabt",
        ),
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
        "exam_name": "AYT",
        "sessions": (("ayt", "", 80),),
        "short_aliases": (
            "ayt sayısal",
            "ayt sayisal",
            "ayt sözel",
            "ayt sozel",
            "ayt eşit ağırlık",
            "ayt esit agirlik",
            "ayt dil",
        ),
    },
    {
        "family": "DGS",
        "exam_name": "DGS",
        "sessions": (("dgs", "DGS", 120),),
    },
    {
        "family": "Kaymakamlık",
        "exam_name": "Kaymakamlık",
        "sessions": (("all", "", 120),),
        "short_aliases": ("kaymakamlik", "kaymakamlık"),
    },
    {
        "family": "Hakimlik",
        "exam_name": "HMGS",
        "sessions": (("1", "", 100),),
        "label_template": "{year}-HMGS/{session_key}",
        "short_aliases": (
            "hmgs",
            "hmgs/1",
            "hakimlik",
            "adli",
            "adli yargı",
            "adli yargi",
            "adli hakimlik",
            "adli yargı hakimliği",
            "adli yargi hakimligi",
            "idari",
            "idari yargı",
            "idari yargi",
            "idari hakimlik",
            "idari yargı hakimliği",
            "idari yargi hakimligi",
        ),
    },
    {
        "family": "Hakimlik",
        "exam_name": "İYÖS",
        "sessions": (("1", "", 100),),
        "label_template": "{year}-İYÖS/{session_key}",
        "short_aliases": (
            "iyös",
            "iyos",
            "iyös/1",
            "iyos/1",
        ),
    },
)

# Ön lisans / ortaöğretim yalnızca çift yıllarda (uygulama ExamType.even_years_only ile aynı).
_KPSS_EVEN_YEARS_ONLY_EXAMS = frozenset({"KPSS Önlisans", "KPSS Ortaöğretim"})

DEFAULT_YEARS = range(2019, 2027)


def archive_key_from_label(raw: str) -> str:
    """Soru numarası sonekini atıp arşiv anahtarını döndürür."""
    normalized = normalize_osym_cikmis_label(raw)
    if not normalized:
        return ""
    return _collapse_legacy_exam_labels(
        normalize_osym_cikmis_label(SORU_SUFFIX_RE.sub("", normalized))
    )


def _collapse_legacy_exam_labels(key: str) -> str:
    """Eski YKS / HMGS / İYÖS / KPSS / AGS / ÖABT etiketlerini güncel katalog biçimine indirger."""
    match = _AYT_LEGACY_EXAM_RE.match(key)
    if match:
        return f"{match.group(1)} AYT"
    match = _HMGS_LEGACY_EXAM_RE.match(key)
    if match:
        return f"{match.group(1)}-HMGS/1"
    match = _HMGS_LOOSE_RE.match(key)
    if match:
        session = match.group(2) or "1"
        return f"{match.group(1)}-HMGS/{session}"
    match = _IYOS_LOOSE_RE.match(key)
    if match:
        session = match.group(2) or "1"
        return f"{match.group(1)}-İYÖS/{session}"
    match = _KPSS_GYGK_LEGACY_RE.match(key)
    if match:
        return match.group(1).strip()
    match = _AGS_LEGACY_SESSION_RE.match(key)
    if match:
        return f"{match.group(1)} AGS"
    match = _OABT_LOOSE_RE.match(key)
    if match:
        return f"{match.group(1)} ÖABT"
    match = _AGS_BRANCH_RE.match(key)
    if match:
        return f"{match.group(1)} AGS"
    return _collapse_redundant_session_suffix(key)


def _alias_fold(text: str) -> str:
    """Türkçe ı/i farkını yok sayarak etiket karşılaştırır."""
    return (text or "").casefold().replace("ı", "i").replace("â", "a")


def _session_suffix_redundant(exam_name: str, session: str) -> bool:
    """Oturum adı sınav adıyla aynıysa «· oturum» soneki gereksizdir (ör. DGS · DGS)."""
    exam_f = _alias_fold((exam_name or "").strip())
    sess_f = _alias_fold((session or "").strip())
    if not sess_f or not exam_f:
        return False
    return sess_f == exam_f


def _collapse_redundant_session_suffix(key: str) -> str:
    """«2026 DGS · DGS» / «2026 ALES · ALES» → «2026 DGS» / «2026 ALES»."""
    if LABEL_SEPARATOR not in key:
        return key
    left, _, right = key.partition(LABEL_SEPARATOR)
    left = left.strip()
    right = right.strip()
    if not left or not right:
        return key
    match = YEAR_PREFIX_RE.match(left)
    if not match:
        return key
    exam_part = match.group(2).strip()
    if _session_suffix_redundant(exam_part, right):
        return left
    return key


def resolve_to_catalog_key(raw: str) -> str:
    """Kısa etiketleri katalog kanoniğine bağlar.

    Örnekler:
    - «2026 AGS» / «2025 AGS · MEB Akademi Giriş Sınavı» → «2026 AGS» / «2025 AGS»
    - «2025 TARİH ÖABT» / «2025 OABT» → «2025 ÖABT»
    - «2025 KPSS Lisans» → «2025 KPSS Lisans»
    - «2025 KPSS Lisans · GYGK» → «2025 KPSS Lisans»
    - «2026 KPSS A» → «2026 KPSS A Grubu»
    - «2026 DGS» / «2026 DGS · DGS» → «2026 DGS»
    - «2025 Kaymakamlık» → «2025 Kaymakamlık» (GYGK / alan ayrılmaz)
    - «2025 adli» / «2025 Hakimlik» → «2025-HMGS/1»
    - «2026-HMGS/1» → «2026-HMGS/1»
    - «2024 İYÖS» / «2024 iyos» → «2024-İYÖS/1»
    """
    key = archive_key_from_label(raw)
    if not key:
        return ""

    year, _rest = parse_archive_key(key)
    years = [year] if year is not None else list(DEFAULT_YEARS)
    slots = list(iter_catalog_slots(years=years))

    aliases: dict[str, str] = {}
    family_slots: dict[str, list[str]] = defaultdict(list)
    exam_slots: dict[str, list[str]] = defaultdict(list)

    for y, slot in slots:
        canon = slot.canonical_label(y)
        aliases[_alias_fold(canon)] = canon
        exam_key = f"{y} {slot.exam_name}"
        exam_slots[_alias_fold(exam_key)].append(canon)
        family_slots[_alias_fold(f"{y} {slot.family}")].append(canon)
        aliases[
            _alias_fold(f"{y} {slot.exam_name}{LABEL_SEPARATOR}{slot.session_key}")
        ] = canon
        aliases[
            _alias_fold(
                f"{y} {slot.exam_name}{LABEL_SEPARATOR}{slot.session_key.upper()}"
            )
        ] = canon

    for template in _EXAM_TEMPLATES:
        label_template = str(template.get("label_template") or "")
        for session_key, session_name, expected in template["sessions"]:
            for y in years:
                slot = OsymArchiveSlot(
                    family=template["family"],
                    exam_name=template["exam_name"],
                    session_key=session_key,
                    session_name=session_name,
                    expected_count=expected,
                    label_template=label_template,
                )
                canon = slot.canonical_label(y)
                for short in template.get("short_aliases") or ():
                    aliases[_alias_fold(f"{y} {short}")] = canon
                    aliases[
                        _alias_fold(f"{y} {short}{LABEL_SEPARATOR}{session_key}")
                    ] = canon
                    aliases[_alias_fold(f"{y}-{short}")] = canon

    for family_key, canons in family_slots.items():
        unique = list(dict.fromkeys(canons))
        if len(unique) == 1:
            aliases[family_key] = unique[0]

    for exam_key, canons in exam_slots.items():
        unique = list(dict.fromkeys(canons))
        if len(unique) == 1:
            aliases[exam_key] = unique[0]

    # Tek yılda A Grubu da var; çıplak «YYYY KPSS» yine Lisans demektir.
    for y in years:
        if y % 2 == 1:
            aliases[_alias_fold(f"{y} KPSS")] = f"{y} KPSS Lisans"

    return aliases.get(_alias_fold(key), key)


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
            exam_name = template["exam_name"]
            if year % 2 == 1 and exam_name in _KPSS_EVEN_YEARS_ONLY_EXAMS:
                continue
            label_template = str(template.get("label_template") or "")
            for session_key, session_name, expected in template["sessions"]:
                yield year, OsymArchiveSlot(
                    family=template["family"],
                    exam_name=exam_name,
                    session_key=session_key,
                    session_name=session_name,
                    expected_count=expected,
                    label_template=label_template,
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
        key = resolve_to_catalog_key(row["osym_cikmis_adi"])
        if not key:
            continue
        bucket = merged[_alias_fold(key)]
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
    bucket = counts.get(_alias_fold(label), {"active": 0, "total": 0, "unpublished": 0})
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
        _alias_fold(slot.canonical_label(year))
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
        active = int(counts.get(_alias_fold(label), {}).get("active", 0))
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
    target = _alias_fold(resolve_to_catalog_key(archive_key))
    if not target:
        return []
    qs = Question.objects.filter(osym_sordu=True).select_related("topic", "topic__subject")
    if published_only:
        qs = qs.filter(is_published=True)
    matched: list[Question] = []
    for q in qs:
        if _alias_fold(resolve_to_catalog_key(q.osym_cikmis_adi)) == target:
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


# Telegram alt yazısı: «2025 TARİH ÖABT», «2026 KPSS Lisans» gibi arşiv etiketleri.
# Serbest çözüm metninden ayırmak için bilinen sınav jetonları.
_CAPTION_EXAM_TOKEN_RE = re.compile(
    r"(?i)(?<![A-Za-zÇĞİÖŞÜçğıöşü])"
    r"(?:"
    r"öabt|oabt|"
    r"kpss|"
    r"dgs|"
    r"ales|"
    r"ags|"
    r"hmgs|"
    r"iy[öo]s|"
    r"tyt|"
    r"ayt|"
    r"yks|"
    r"ms[üu]|"
    r"kaymakaml[iı]k"
    r")"
    r"(?![A-Za-zÇĞİÖŞÜçğıöşü])"
)


def parse_telegram_caption_archive_label(raw: str) -> str:
    """Alt yazı yıl + sınav etiketi ise kanonik/normalized etiket döndürür.

    Yalnızca kısa etiket satırları (ör. «2025 TARİH ÖABT», «2026 KPSS Lisans»).
    Uzun serbest çözüm metni → boş string.
    """
    if not (raw or "").strip():
        return ""
    # Çok satırlı alt yazıda yalnızca satır satır kontrol edilir (çağıran taraf).
    if "\n" in raw or "\r" in raw:
        return ""
    text = normalize_osym_cikmis_label(raw)
    if not text:
        return ""
    if len(text) > 80 or len(text.split()) > 8:
        return ""
    if any(ch in text for ch in ".?!;:"):
        return ""
    if not YEAR_PREFIX_RE.match(text):
        return ""
    if not _CAPTION_EXAM_TOKEN_RE.search(text):
        return ""
    return resolve_to_catalog_key(text) or text
