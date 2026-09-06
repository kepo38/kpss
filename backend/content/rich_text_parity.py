"""Rich-text parity fixture yükleyici — Python/Dart/JS golden testleri."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from .rich_text_storage import normalize_field

_FIXTURE_PATH = Path(__file__).resolve().parent / "fixtures" / "rich_text_parity.json"


@lru_cache(maxsize=1)
def load_parity_fixtures() -> list[dict[str, Any]]:
    data = json.loads(_FIXTURE_PATH.read_text(encoding="utf-8"))
    cases = data.get("cases") or []
    if not isinstance(cases, list):
        raise ValueError("rich_text_parity.json: cases must be a list")
    return cases


def parity_fixture_path() -> Path:
    return _FIXTURE_PATH


def compute_expected(field: str, text: str, *, html: str = "") -> str:
    return normalize_field(field, text, html=html)


def regenerate_fixture_expected(dry_run: bool = False) -> int:
    """Fixture dosyasındaki ``expected`` alanlarını Python pipeline ile güncelle."""
    raw = json.loads(_FIXTURE_PATH.read_text(encoding="utf-8"))
    cases = raw.get("cases") or []
    updated = 0
    for case in cases:
        field = case.get("field") or "solution"
        inp = case.get("input") or ""
        html = case.get("html") or ""
        from .rich_text_common import choose_paste_text

        prev_effective = case.get("effective_input")
        case["effective_input"] = choose_paste_text(inp, html)
        expected = compute_expected(field, inp, html=html)
        if case.get("expected") != expected:
            case["expected"] = expected
            updated += 1
        elif prev_effective != case["effective_input"]:
            updated += 1
    if not dry_run and updated:
        _FIXTURE_PATH.write_text(
            json.dumps(raw, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return updated
