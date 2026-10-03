"""Çözüm metnindeki storage enkazını toplu onar.

``solution_has_storage_defects`` / ``repair_solution_storage_defects`` /
``normalize_pasted_solution`` zincirini kullanır (MSO, XPM, hphantom,
token-expansion, Docs annotation JSON, yapışık math, …).

Kayıt sırasında da aynı scrub çalışır; bu komut mevcut DB kayıtlarını
toplu tarar. Ağır enkazda metin kısmen düzelir — kalanları listeler.
"""

from __future__ import annotations

import re

from django.core.management.base import BaseCommand
from django.db import transaction

from content.models import Question
from content.rich_text_common import (
    repair_solution_storage_defects,
    solution_has_storage_defects,
)
from content.rich_text_panel import normalize_pasted_solution

def _candidate(text: str) -> bool:
    return solution_has_storage_defects(text or "")


def _needs_human_rewrite(text: str) -> bool:
    """Otomatik scrub sonrası hâlâ kusurlu / yalnızca placeholder."""
    src = (text or "").strip()
    if not src:
        return True
    if solution_has_storage_defects(src):
        return True
    compact = re.sub(r"\s+", "", src)
    # [ŞEKİL] / [SEKIL] / ... only
    if re.fullmatch(r"(?:\[[^\]]*\]|\.+|…)+", compact, flags=re.IGNORECASE):
        upper = compact.upper().replace("İ", "I").replace("Ş", "S")
        if "SEKIL" in upper or compact in {"...", "…", "."}:
            return True
    return False


class Command(BaseCommand):
    help = (
        "Çözümlerdeki storage enkazını (MSO/XPM/hphantom/token/Docs JSON…) "
        "normalize_pasted_solution ile temizler (--dry-run ile yalnız listeler)."
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
        candidates = 0
        changed = 0
        still_dirty: list[str] = []
        human_rewrite: list[str] = []

        for question in qs.iterator(chunk_size=200):
            scanned += 1
            old = question.solution or ""
            if not _candidate(old):
                continue
            candidates += 1

            repaired = repair_solution_storage_defects(old)
            new = normalize_pasted_solution(repaired)
            # normalize no-op / kısa yol kaçırırsa bir kez daha dokun
            if solution_has_storage_defects(new):
                new = normalize_pasted_solution(repair_solution_storage_defects(new))

            if new == old:
                if _needs_human_rewrite(old):
                    human_rewrite.append(question.public_id)
                    still_dirty.append(question.public_id)
                continue

            changed += 1
            self.stdout.write(
                f"{'[dry] ' if dry_run else ''}"
                f"{question.public_id}: {len(old)} -> {len(new)} karakter"
            )
            if _needs_human_rewrite(new):
                human_rewrite.append(question.public_id)
                still_dirty.append(question.public_id)
            if not dry_run:
                with transaction.atomic():
                    Question.objects.filter(pk=question.id).update(solution=new)

            if limit and changed >= limit:
                break

        self.stdout.write(
            self.style.SUCCESS(
                f"Tarama: {scanned} · aday: {candidates} · değişen: {changed}"
                + (" (dry-run)" if dry_run else "")
            )
        )
        self.stdout.write(
            f"Hâlâ kusurlu / insan yeniden yazımı: {len(human_rewrite)}"
        )
        if still_dirty:
            self.stdout.write(
                self.style.WARNING(
                    "Hâlâ enkazli / elle bakilmali: "
                    + ", ".join(still_dirty[:40])
                    + (" ..." if len(still_dirty) > 40 else "")
                )
            )
