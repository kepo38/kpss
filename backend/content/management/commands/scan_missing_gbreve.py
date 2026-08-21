"""Scan / optionally repair stems where Turkish ğ was replaced by whitespace."""

from __future__ import annotations

import re

from django.core.management.base import BaseCommand

from content.models import Question
from content.ocr import normalize_turkish_text
from content.question_fingerprint import apply_fingerprints

_SCAN_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("gerekti_ws_ini", re.compile(r"gerekti[\s\u00a0]+ini", re.I)),
    ("oldugu_ws_un", re.compile(r"oldugu[\s\u00a0]+un[ua]", re.I)),
    ("mojibake_markers", re.compile(r"Ã.|Â.|Ä.|Å.")),
    ("cp1254_eth", re.compile(r"[ðÐ]")),
)

_FIELDS = (
    "stem",
    "option_a",
    "option_b",
    "option_c",
    "option_d",
    "option_e",
    "solution",
)


def _mojibake_improved(before: str, after: str) -> bool:
    markers = ("Ã", "Â", "Ä", "Å")
    return sum(after.count(c) for c in markers) < sum(
        before.count(c) for c in markers
    )


def _gbreve_space_fixed(before: str, after: str) -> bool:
    return bool(
        re.search(r"gerekti[\s\u00a0]+ini", before, re.I)
        and "gerektiğini" in after
    ) or bool(
        re.search(r"oldugu[\s\u00a0]+un[ua]", before, re.I)
        and re.search(r"olduğun[ua]", after)
    )


def _should_write(before: str, after: str) -> bool:
    if after == before:
        return False
    if after.replace("\r", "") == (before or "").replace("\r", "").strip():
        return False
    return _mojibake_improved(before, after) or _gbreve_space_fixed(
        before, after
    )


class Command(BaseCommand):
    help = (
        "Soru metinlerinde kayıp ğ / mojibake tarar. "
        "--fix yalnızca normalize_turkish_text güvenli kalıplarını kaydeder."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--fix",
            action="store_true",
            help="normalize_turkish_text ile güvenli onarımları kaydet",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=30,
            help="Örnek satır üst sınırı (varsayılan 30)",
        )

    def handle(self, *args, **options):
        do_fix = bool(options["fix"])
        limit = max(1, int(options["limit"]))

        hits: dict[str, list[tuple[str, str, str]]] = {
            key: [] for key, _ in _SCAN_PATTERNS
        }
        counts = {key: 0 for key, _ in _SCAN_PATTERNS}
        fixed = 0
        scanned = 0

        qs = Question.objects.all().only("id", "public_id", *_FIELDS)
        for question in qs.iterator():
            scanned += 1
            matched_keys: set[str] = set()
            changed = False

            for field in _FIELDS:
                raw = getattr(question, field) or ""
                for key, pat in _SCAN_PATTERNS:
                    m = pat.search(raw)
                    if not m:
                        continue
                    matched_keys.add(key)
                    if len(hits[key]) < limit:
                        a = max(0, m.start() - 24)
                        b = min(len(raw), m.end() + 24)
                        snip = raw[a:b].replace("\n", "\\n")
                        hits[key].append((question.public_id, field, snip))

                if not do_fix:
                    continue
                repaired = normalize_turkish_text(raw)
                if _should_write(raw, repaired):
                    setattr(question, field, repaired)
                    changed = True

            for key in matched_keys:
                counts[key] += 1

            if changed:
                apply_fingerprints(question)
                question.save()
                fixed += 1
                self.stdout.write(
                    self.style.SUCCESS(f"fixed {question.public_id}")
                )

        self.stdout.write(f"questions scanned: {scanned}")
        for key, _ in _SCAN_PATTERNS:
            self.stdout.write(f"\n[{key}] questions={counts[key]}")
            for pid, field, snip in hits[key]:
                self.stdout.write(f"  {pid} {field}: …{snip}…")
            if counts[key] > len(hits[key]):
                self.stdout.write(
                    f"  … +{counts[key] - len(hits[key])} more questions"
                )

        if do_fix:
            self.stdout.write(self.style.SUCCESS(f"\nrepaired rows: {fixed}"))
        else:
            self.stdout.write(
                "\nDry-run only. Re-run with --fix to apply safe repairs."
            )
