"""Parity golden tests — normalize_field == fixture expected (idempotent)."""

from django.test import SimpleTestCase

from content.rich_text_parity import (
    compute_expected,
    load_parity_fixtures,
    regenerate_fixture_expected,
)
from content.rich_text_storage import normalize_field


class RichTextParityFixtureTests(SimpleTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        missing = [
            c["id"]
            for c in load_parity_fixtures()
            if "expected" not in c or c["expected"] is None
        ]
        if missing:
            regenerate_fixture_expected()

    def test_all_fixtures_have_expected(self):
        for case in load_parity_fixtures():
            with self.subTest(case_id=case["id"]):
                self.assertIn(
                    "expected",
                    case,
                    msg=f"Run: python manage.py regenerate_rich_text_parity",
                )
                self.assertIsInstance(case["expected"], str)

    def test_normalize_matches_expected(self):
        for case in load_parity_fixtures():
            with self.subTest(case_id=case["id"]):
                field = case.get("field") or "solution"
                out = normalize_field(
                    field,
                    case.get("input") or "",
                    html=case.get("html") or "",
                )
                self.assertEqual(out, case["expected"])

    def test_normalize_is_idempotent(self):
        for case in load_parity_fixtures():
            with self.subTest(case_id=case["id"]):
                field = case.get("field") or "solution"
                once = case["expected"]
                twice = normalize_field(field, once)
                self.assertEqual(twice, once)

    def test_compute_expected_helper(self):
        case = load_parity_fixtures()[0]
        self.assertEqual(
            compute_expected(
                case["field"],
                case.get("input") or "",
                html=case.get("html") or "",
            ),
            case["expected"],
        )
