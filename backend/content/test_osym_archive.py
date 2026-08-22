"""ÖSYM arşiv etiket ayrıştırma testleri."""

from django.test import SimpleTestCase

from content.osym_archive import (
    OsymArchiveSlot,
    archive_key_from_label,
    archive_families,
    parse_archive_key,
)


class OsmArchiveLabelTests(SimpleTestCase):
    def test_strips_soru_suffix(self):
        raw = "2025 KPSS Lisans · Genel Yetenek - Genel Kültür · Soru 12"
        self.assertEqual(
            archive_key_from_label(raw),
            "2025 KPSS Lisans · Genel Yetenek - Genel Kültür",
        )

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
