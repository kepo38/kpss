from django.test import SimpleTestCase

from content.osym_exam_order import (
    OSYM_FULL_EXAM,
    OSYM_TURKCE,
    full_exam_slot_count,
    scale_osym_slots,
    subject_canonical_key,
)


class OsymExamOrderTests(SimpleTestCase):
    def test_full_exam_totals_120(self):
        self.assertEqual(full_exam_slot_count(), 120)
        self.assertEqual(sum(s.count for s in OSYM_FULL_EXAM), 120)

    def test_turkish_branch_scaled_to_27(self):
        scaled = scale_osym_slots(OSYM_TURKCE, 27)
        self.assertEqual(sum(s.count for s in scaled), 27)
        # Paragraf bloğu en büyük payı korur.
        paragraf = next(s for s in scaled if "turkce_paragraf" in s.topic_slugs)
        self.assertGreaterEqual(paragraf.count, 10)

    def test_subject_canonical_key_aliases(self):
        self.assertEqual(subject_canonical_key("turkce_anlam"), "turkce")
        self.assertEqual(subject_canonical_key("guncel_bilgiler"), "guncel")
        self.assertEqual(subject_canonical_key("matematik"), "matematik")

    def test_scale_preserves_order(self):
        scaled = scale_osym_slots(OSYM_TURKCE, 27)
        keys = [s.topic_slugs[0] if s.topic_slugs else "" for s in scaled]
        self.assertEqual(keys[0], "turkce_anlam")
        self.assertEqual(keys[-1], "turkce_sozel_mantik")
