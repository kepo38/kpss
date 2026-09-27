"""Çözüm metnindeki ``\\hphantom`` / yapışık math enkazını toplu onar.

Kayıt sırasında da aynı scrub çalışır; bu komut mevcut DB kayıtlarını
toplu tarar. Ağır enkazda metin kısmen düzelir — kalanları listeler.
"""

from __future__ import annotations

from django.core.management.base import BaseCommand
from django.db import transaction

from content.models import Question
from content.rich_text_common import (
    looks_like_glued_duplicate_math,
    looks_like_xpm_html_attribute_debris,
    scrub_glued_duplicate_math,
    scrub_hphantom_math_debris,
    scrub_xpm_html_attribute_debris,
)
from content.rich_text_panel import normalize_pasted_solution


def _candidate(text: str) -> bool:
    src = text or ""
    if "hphantom" in src or "\\phantom" in src:
        return True
    if looks_like_xpm_html_attribute_debris(src):
        return True
    return looks_like_glued_duplicate_math(src)


def _still_dirty(text: str) -> bool:
    src = text or ""
    if "hphantom" in src or "\\phantom" in src:
        return True
    if looks_like_xpm_html_attribute_debris(src):
        return True
    return looks_like_glued_duplicate_math(src)


class Command(BaseCommand):
    help = (
        "Çözümlerdeki \\hphantom / yapışık tekrarlı LaTeX enkazını temizler "
        "(--dry-run ile yalnız listeler)."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Yazmadan tarayıp etkilenen public_id listesini bas.",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="En fazla N kayıt (0 = hepsi).",
        )

    def handle(self, *args, **options) -> None:
        dry_run = bool(options["dry_run"])
        limit = int(options["limit"] or 0)

        qs = (
            Question.objects.exclude(solution="")
            .only("id", "public_id", "solution")
            .order_by("id")
        )
        scanned = 0
        changed = 0
        still_dirty: list[str] = []

        for question in qs.iterator(chunk_size=200):
            scanned += 1
            old = question.solution or ""
            if not _candidate(old):
                continue

            scrubbed = scrub_xpm_html_attribute_debris(old)
            scrubbed = scrub_hphantom_math_debris(scrubbed)
            scrubbed = scrub_glued_duplicate_math(scrubbed)
            new = normalize_pasted_solution(scrubbed)
            if "hphantom" in new or "\\phantom" in new:
                new = scrub_hphantom_math_debris(new)
            if looks_like_xpm_html_attribute_debris(new):
                new = scrub_xpm_html_attribute_debris(new)
            if looks_like_glued_duplicate_math(new):
                new = scrub_glued_duplicate_math(new)
            if new == old:
                if _still_dirty(old):
                    still_dirty.append(question.public_id)
                continue

            changed += 1
            self.stdout.write(
                f"{'[dry] ' if dry_run else ''}"
                f"{question.public_id}: {len(old)} -> {len(new)} karakter"
            )
            if _still_dirty(new):
                still_dirty.append(question.public_id)
            if not dry_run:
                with transaction.atomic():
                    Question.objects.filter(pk=question.id).update(solution=new)

            if limit and changed >= limit:
                break

        self.stdout.write(
            self.style.SUCCESS(
                f"Tarama: {scanned} · değişen: {changed}"
                + (" (dry-run)" if dry_run else "")
            )
        )
        if still_dirty:
            self.stdout.write(
                self.style.WARNING(
                    "Hâlâ enkazli / elle bakilmali: "
                    + ", ".join(still_dirty[:40])
                    + (" ..." if len(still_dirty) > 40 else "")
                )
            )
