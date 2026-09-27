"""ÖSYM arşiv etiket ayrıştırma testleri."""

from django.test import SimpleTestCase

from content.osym_archive import (
    OsymArchiveSlot,
    archive_key_from_label,
    archive_families,
    parse_archive_key,
    resolve_to_catalog_key,
)


class OsmArchiveLabelTests(SimpleTestCase):
    def test_strips_soru_suffix(self):
        raw = "2025 KPSS Lisans · Genel Yetenek - Genel Kültür · Soru 12"
        self.assertEqual(archive_key_from_label(raw), "2025 KPSS Lisans")

    def test_parse_year_and_rest(self):
        year, rest = parse_archive_key("2024 TYT · Temel Yeterlilik Testi")
        self.assertEqual(year, 2024)
        self.assertEqual(rest, "TYT · Temel Yeterlilik Testi")

    def test_empty_label(self):
        self.assertEqual(archive_key_from_label(""), "")
        self.assertEqual(archive_key_from_label("   "), "")

    def test_ags_catalog_slot(self):
        slot = OsymArchiveSlot(
            family="AGS",
            exam_name="AGS",
            session_key="ags",
            session_name="MEB Akademi Giriş Sınavı",
            expected_count=80,
        )
        self.assertEqual(
            slot.canonical_label(2025),
            "2025 AGS · MEB Akademi Giriş Sınavı",
        )
        self.assertIn("AGS", archive_families())

    def test_dgs_canonical_label_omits_redundant_session(self):
        slot = OsymArchiveSlot(
            family="DGS",
            exam_name="DGS",
            session_key="dgs",
            session_name="DGS",
            expected_count=120,
        )
        self.assertEqual(slot.canonical_label(2026), "2026 DGS")
        self.assertEqual(resolve_to_catalog_key("2026 DGS"), "2026 DGS")
        self.assertEqual(resolve_to_catalog_key("2026 DGS · DGS"), "2026 DGS")
        self.assertEqual(archive_key_from_label("2026 DGS · DGS"), "2026 DGS")

    def test_ales_canonical_label_omits_redundant_session(self):
        slot = OsymArchiveSlot(
            family="ALES",
            exam_name="ALES",
            session_key="ales",
            session_name="ALES",
            expected_count=100,
        )
        self.assertEqual(slot.canonical_label(2025), "2025 ALES")
        self.assertEqual(resolve_to_catalog_key("2025 ALES · ALES"), "2025 ALES")

    def test_useful_session_suffix_still_kept(self):
        # AGS / TYT oturum açıklaması sınav adından farklı → sonek kalır.
        tyt = OsymArchiveSlot(
            family="YKS",
            exam_name="TYT",
            session_key="tyt",
            session_name="Temel Yeterlilik Testi",
            expected_count=120,
        )
        self.assertEqual(
            tyt.canonical_label(2024),
            "2024 TYT · Temel Yeterlilik Testi",
        )
        self.assertEqual(
            resolve_to_catalog_key("2026-HMGS/1"),
            "2026-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 KPSS Lisans"),
            "2025 KPSS Lisans",
        )

    def test_short_ags_label_resolves_to_catalog(self):
        self.assertEqual(
            resolve_to_catalog_key("2026 AGS"),
            "2026 AGS · MEB Akademi Giriş Sınavı",
        )

    def test_ambiguous_kpss_short_label_stays_on_even_year(self):
        # Çift yılda Lisans / Önlisans / Ortaöğretim birlikte → «KPSS» belirsiz.
        self.assertEqual(resolve_to_catalog_key("2026 KPSS"), "2026 KPSS")
        self.assertEqual(resolve_to_catalog_key("2024 KPSS"), "2024 KPSS")

    def test_odd_year_kpss_short_label_means_lisans(self):
        # Tek yılda yalnızca Lisans var → «2025 KPSS» Lisans oturumuna bağlanır.
        self.assertEqual(resolve_to_catalog_key("2025 KPSS"), "2025 KPSS Lisans")

    def test_odd_year_catalog_skips_onlisans_ortaogretim(self):
        from content.osym_archive import iter_catalog_slots

        odd_names = {slot.exam_name for year, slot in iter_catalog_slots(years=[2025]) if slot.family == "KPSS"}
        even_names = {slot.exam_name for year, slot in iter_catalog_slots(years=[2026]) if slot.family == "KPSS"}
        self.assertEqual(odd_names, {"KPSS Lisans", "KPSS A Grubu"})
        self.assertEqual(
            even_names,
            {"KPSS Lisans", "KPSS Önlisans", "KPSS Ortaöğretim", "KPSS A Grubu"},
        )

    def test_kpss_a_short_label_resolves(self):
        self.assertEqual(
            resolve_to_catalog_key("2026 KPSS A"),
            "2026 KPSS A Grubu",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 A Grubu"),
            "2025 KPSS A Grubu",
        )
        self.assertEqual(
            resolve_to_catalog_key("2024 KPSS A Grubu"),
            "2024 KPSS A Grubu",
        )

    def test_kpss_lisans_without_session_resolves(self):
        self.assertEqual(
            resolve_to_catalog_key("2025 KPSS Lisans"),
            "2025 KPSS Lisans",
        )

    def test_kpss_lisans_gygk_alias_resolves(self):
        self.assertEqual(
            resolve_to_catalog_key("2025 KPSS Lisans · GYGK"),
            "2025 KPSS Lisans",
        )
        self.assertEqual(
            resolve_to_catalog_key(
                "2026 KPSS Lisans · Genel Yetenek - Genel Kültür"
            ),
            "2026 KPSS Lisans",
        )

    def test_kaymakamlik_and_hakimlik_families(self):
        families = archive_families()
        self.assertIn("Kaymakamlık", families)
        self.assertIn("Hakimlik", families)
        self.assertEqual(
            resolve_to_catalog_key("2025 Kaymakamlık"),
            "2025 Kaymakamlık",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 kaymakamlik"),
            "2025 Kaymakamlık",
        )
        self.assertEqual(
            resolve_to_catalog_key("2026-HMGS/1"),
            "2026-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 Adli Yargı Hakimliği"),
            "2025-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 İdari Yargı Hakimliği"),
            "2025-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 adli"),
            "2025-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 idari"),
            "2025-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 Hakimlik"),
            "2025-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2026 HMGS"),
            "2026-HMGS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2024-İYÖS/1"),
            "2024-İYÖS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2024 İYÖS"),
            "2024-İYÖS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2024 iyos"),
            "2024-İYÖS/1",
        )
        self.assertEqual(
            resolve_to_catalog_key("2024 İYÖS/1"),
            "2024-İYÖS/1",
        )
        self.assertEqual(
            archive_key_from_label("2024 İYÖS · Soru 3"),
            "2024-İYÖS/1",
        )

    def test_ayt_short_label_resolves_to_catalog(self):
        slot = OsymArchiveSlot(
            family="YKS",
            exam_name="AYT",
            session_key="ayt",
            session_name="",
            expected_count=80,
        )
        self.assertEqual(slot.canonical_label(2026), "2026 AYT")
        self.assertEqual(resolve_to_catalog_key("2026 AYT"), "2026 AYT")

    def test_legacy_ayt_subtypes_collapse(self):
        self.assertEqual(
            archive_key_from_label("2026 AYT Eşit Ağırlık · Alan Yeterlilik Testi"),
            "2026 AYT",
        )
        self.assertEqual(
            resolve_to_catalog_key("2025 AYT Sayısal"),
            "2025 AYT",
        )
        self.assertEqual(
            resolve_to_catalog_key("2024 AYT Dil · Yabancı Dil Testi"),
            "2024 AYT",
        )
