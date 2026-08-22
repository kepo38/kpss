"""ÖSYM arşiv etiket ayrıştırma testleri."""

from django.test import SimpleTestCase

from content.osym_archive import (
    archive_key_from_label,
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
