"""``__## …__`` / ``__1. Aşama …__`` blok altı çizgili çözüm başlıklarını onar.

Yalnızca ``demote_block_underline_markup`` uygular; tam çözüm normalizasyonu
(outline yeniden yapılandırma, LaTeX, madde birleştirme vb.) **yapılmaz**.
"""

from __future__ import annotations

import re

from django.core.management.base import BaseCommand
from django.db import transaction

from content.models import Question
from content.rich_text_common import (
    needs_block_underline_repair,
    repair_block_underline_solution,
)

_PREVIEW_LINE_RE = re.compile(
    r"(?m)^[ \t]*__(?:#{1,3}\s+|\d+\.\s*(?:Aşama|Adım)\b|\*\*.+\*\*).+__\s*$",
    re.IGNORECASE,
)


def _preview_lines(text: str, limit: int = 3) -> list[str]:
    out: list[str] = []
    for line in (text or "").split("\n"):
        if _PREVIEW_LINE_RE.match(line):
            out.append(line.strip())
        if len(out) >= limit:
            break
    return out


class Command(BaseCommand):
    help = (
        "Çözüm metnindeki __## / __1. Aşama__ gibi tam satır altı çizgili "
        "başlıkları **kalın** biçime indirger (dar kapsamlı onarım)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Kaydetmeden adayları ve örnek satırları listele.",
        )
        parser.add_argument(
            "--public-id",
            action="append",
            dest="public_ids",
            help="Yalnızca belirtilen public_id (tekrarlanabilir).",
        )
        parser.add_argument(
            "--pk",
            type=int,
            action="append",
            dest="pks",
            help="Yalnızca belirtilen soru pk (tekrarlanabilir).",
        )
        parser.add_argument(
            "--include-unpublished",
            action="store_true",
            help="Yayınlanmamış soruları da tara (varsayılan: hepsi).",
        )

    def handle(self, *args, **options):
        dry_run = bool(options["dry_run"])
        public_ids = options.get("public_ids") or []
        pks = options.get("pks") or []

        qs = Question.objects.exclude(solution="").exclude(solution__isnull=True)
        if public_ids:
            qs = qs.filter(public_id__in=public_ids)
        elif pks:
            qs = qs.filter(pk__in=pks)
        qs = qs.order_by("pk")

        candidates: list[Question] = []
        for question in qs.iterator():
            if needs_block_underline_repair(question.solution):
                candidates.append(question)

        if not candidates:
            self.stdout.write(
                self.style.SUCCESS(
                    "Onarılacak soru yok (taranan: "
                    f"{qs.count()}, __## / blok başlık altı çizgisi: 0)."
                )
            )
            return

        self.stdout.write(
            f"Aday: {len(candidates)} soru "
            f"({'dry-run' if dry_run else 'kaydedilecek'})."
        )

        updated = 0
        pending: list[Question] = []

        for question in candidates:
            old = question.solution
            new = repair_block_underline_solution(old)
            if new == old:
                continue

            preview = _preview_lines(old)
            self.stdout.write(
                f"- {question.public_id} (pk={question.pk}) "
                f"satır: {len(preview)} örnek"
            )
            for line in preview:
                self.stdout.write(f"    eski: {line[:120]}")
                repaired_line = repair_block_underline_solution(line)
                if repaired_line != line:
                    self.stdout.write(f"    yeni: {repaired_line[:120]}")

            if not dry_run:
                question.solution = new
                pending.append(question)
                updated += 1
            else:
                updated += 1

        if not dry_run and pending:
            with transaction.atomic():
                Question.objects.bulk_update(pending, ["solution"], batch_size=50)

        suffix = " [dry-run]" if dry_run else ""
        self.stdout.write(
            self.style.SUCCESS(
                f"Bitti: {updated} soru {'incelenildi' if dry_run else 'güncellendi'}{suffix}."
            )
        )
