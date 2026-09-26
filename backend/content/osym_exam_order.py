"""ÖSYM TG deneme soru sırası — konu/kronoloji bazlı dağılım.

TG tam deneme (120 soru) ve branş denemeleri aynı mantığı kullanır;
branş denemelerinde slot sayıları orantılı ölçeklenir (ör. Türkçe 27 soru).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class OsymSlot:
    """Tek seçim dilimi: ders anahtarı + konu slug(ları) + soru adedi."""

    subject_key: str
    count: int
    topic_slugs: tuple[str, ...] = ()
    subtopic: str = ""
    scenario_group: bool = False


# — Türkçe (30): anlam → paragraf → dil bilgisi → sözel mantık —
OSYM_TURKCE: tuple[OsymSlot, ...] = (
    OsymSlot("turkce", 3, ("turkce_anlam",)),
    OsymSlot("turkce", 3, ("turkce_cumlede_anlam",)),
    OsymSlot("turkce", 16, ("turkce_paragraf",)),
    OsymSlot("turkce", 2, ("turkce_dilbilgisi",)),
    OsymSlot("turkce", 1, ("turkce_ses",)),
    OsymSlot("turkce", 1, ("turkce_yazim",)),
    OsymSlot("turkce", 1, ("turkce_noktalama",)),
    OsymSlot("turkce", 3, ("turkce_sozel_mantik",), scenario_group=True),
)

# — Matematik (30): temel → denklem → problem → mantık → geometri —
OSYM_MATEMATIK: tuple[OsymSlot, ...] = (
    OsymSlot("matematik", 1, ("mat_rasyonel",)),
    OsymSlot("matematik", 1, ("mat_koklu",)),
    OsymSlot("matematik", 1, ("mat_uslu",)),
    OsymSlot("matematik", 2, ("mat_temel",)),
    OsymSlot("matematik", 5, ("mat_temel",)),
    OsymSlot("matematik", 10, ("mat_problem",)),
    OsymSlot("matematik", 3, ("mat_tablo_grafik",)),
    OsymSlot("matematik", 3, ("mat_sayisal_mantik",)),
    OsymSlot("matematik", 4, ("mat_geometri",)),
)

# — Tarih (27): kronolojik —
OSYM_TARIH: tuple[OsymSlot, ...] = (
    OsymSlot("tarih", 1, ("tarih_islamiyet_oncesi",)),
    OsymSlot("tarih", 2, ("tarih_turk_islam",)),
    OsymSlot("tarih", 3, ("tarih_osmanli_kurulus_yukselme",)),
    OsymSlot("tarih", 1, ("tarih_osmanli_17",)),
    OsymSlot("tarih", 1, ("tarih_osmanli_18",)),
    OsymSlot("tarih", 1, ("tarih_osmanli_19",)),
    OsymSlot("tarih", 1, ("tarih_osmanli_20",)),
    OsymSlot("tarih", 2, ("tarih_osmanli_kultur",)),
    OsymSlot("tarih", 1, ("tarih_kurtulus_hazirlik",)),
    OsymSlot("tarih", 1, ("tarih_tbmm",)),
    OsymSlot("tarih", 3, ("tarih_kurtulus_muharebe",)),
    OsymSlot("tarih", 3, ("tarih_inkilaplar",)),
    OsymSlot("tarih", 1, ("tarih_ilkeler",)),
    OsymSlot("tarih", 1, ("tarih_partiler",)),
    OsymSlot("tarih", 1, ("tarih_dis_politika",)),
    OsymSlot("tarih", 1, ("tarih_sonrasi",)),
    OsymSlot("tarih", 3, ("tarih_cagdas_turk_dunya",)),
)

# — Coğrafya (18): fiziki → beşeri → ekonomik —
OSYM_COGRAFYA: tuple[OsymSlot, ...] = (
    OsymSlot("cografya", 2, ("cog_konum",)),
    OsymSlot("cografya", 3, ("cog_yersekilleri",)),
    OsymSlot("cografya", 2, ("cog_iklim_bitki",)),
    OsymSlot("cografya", 3, ("cog_nufus_yerlesme",)),
    OsymSlot("cografya", 3, ("cog_tarim",)),
    OsymSlot("cografya", 2, ("cog_maden_enerji_sanayi",)),
    OsymSlot("cografya", 3, ("cog_ulasim_ticaret_turizm",)),
)

# — Vatandaşlık (9): soyuttan somuta —
OSYM_VATANDASLIK: tuple[OsymSlot, ...] = (
    OsymSlot("vatandaslik", 3, ("vat_hukuk_temel",)),
    OsymSlot("vatandaslik", 1, ("vat_anayasa_giris", "vat_devlet_demokrasi")),
    OsymSlot("vatandaslik", 1, ("vat_yasama",)),
    OsymSlot("vatandaslik", 1, ("vat_yurutme",)),
    OsymSlot("vatandaslik", 2, ("vat_yargi",)),
    OsymSlot("vatandaslik", 1, ("vat_idare_hukuku",)),
)

# — Güncel (6) —
OSYM_GUNCEL: tuple[OsymSlot, ...] = (
    OsymSlot("guncel", 3, ("guncel_tr",)),
    OsymSlot("guncel", 3, ("guncel_dunya",)),
)

OSYM_FULL_EXAM: tuple[OsymSlot, ...] = (
    *OSYM_TURKCE,
    *OSYM_MATEMATIK,
    *OSYM_TARIH,
    *OSYM_COGRAFYA,
    *OSYM_VATANDASLIK,
    *OSYM_GUNCEL,
)

OSYM_BY_SUBJECT_KEY: dict[str, tuple[OsymSlot, ...]] = {
    "turkce": OSYM_TURKCE,
    "turkce_anlam": OSYM_TURKCE,
    "turkce_dilbilgisi": OSYM_TURKCE,
    "matematik": OSYM_MATEMATIK,
    "tarih": OSYM_TARIH,
    "cografya": OSYM_COGRAFYA,
    "vatandaslik": OSYM_VATANDASLIK,
    "guncel": OSYM_GUNCEL,
    "guncel_bilgiler": OSYM_GUNCEL,
}

OSYM_SUBJECT_TOTALS: dict[str, int] = {
    "turkce": 30,
    "matematik": 30,
    "tarih": 27,
    "cografya": 18,
    "vatandaslik": 9,
    "guncel": 6,
}


def osym_slots_for_subject(subject_slug: str) -> tuple[OsymSlot, ...] | None:
    """Ders slug'ına göre ÖSYM slot dizisi; bilinmiyorsa None."""
    key = (subject_slug or "").strip()
    if not key:
        return None
    if key in OSYM_BY_SUBJECT_KEY:
        return OSYM_BY_SUBJECT_KEY[key]
    for alias, slots in OSYM_BY_SUBJECT_KEY.items():
        if key.startswith(alias):
            return slots
    return None


def scale_osym_slots(
    slots: tuple[OsymSlot, ...],
    target_total: int,
) -> list[OsymSlot]:
    """Slot sayılarını hedef toplama orantılı ölçekle (branş denemeleri)."""
    if target_total <= 0:
        return []
    source_total = sum(s.count for s in slots)
    if source_total <= 0:
        return []

    if target_total == source_total:
        return list(slots)

    scaled_counts: list[int] = []
    remainders: list[tuple[float, int]] = []
    allocated = 0

    for i, slot in enumerate(slots):
        exact = slot.count * target_total / source_total
        base = int(exact)
        scaled_counts.append(base)
        remainders.append((exact - base, i))
        allocated += base

    deficit = target_total - allocated
    for _, index in sorted(remainders, key=lambda row: row[0], reverse=True):
        if deficit <= 0:
            break
        scaled_counts[index] += 1
        deficit -= 1

    result: list[OsymSlot] = []
    for slot, count in zip(slots, scaled_counts):
        if count <= 0:
            continue
        result.append(
            OsymSlot(
                subject_key=slot.subject_key,
                count=count,
                topic_slugs=slot.topic_slugs,
                subtopic=slot.subtopic,
                scenario_group=slot.scenario_group,
            )
        )
    return result


def full_exam_slot_count() -> int:
    return sum(s.count for s in OSYM_FULL_EXAM)


def subject_canonical_key(subject_slug: str) -> str | None:
    """Branş ders slug'ını ÖSYM anahtarına çevirir."""
    key = (subject_slug or "").strip()
    if key in OSYM_BY_SUBJECT_KEY:
        if key in ("turkce_anlam", "turkce_dilbilgisi"):
            return "turkce"
        if key == "guncel_bilgiler":
            return "guncel"
        return key
    if key.startswith("turkce"):
        return "turkce"
    if key.startswith("guncel"):
        return "guncel"
    return key if key in OSYM_SUBJECT_TOTALS else None
