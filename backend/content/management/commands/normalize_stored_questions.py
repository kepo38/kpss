"""DB'deki soru metin alanlarını kayıt-tek-yol pipeline ile toplu normalize et."""

from __future__ import annotations

from django.core.management.base import BaseCommand
from django.db import transaction

from content.models import Question
from content.rich_text_storage import (
    normalize_question_for_storage,
    question_content_changed,
    question_needs_content_normalize,
    snapshot_question_content,
)

_CONTENT_UPDATE_FIELDS = [
    "stem",
    "option_a",
    "option_b",
    "option_c",
    "option_d",
    "option_e",
    "solution",
    "updated_at",
]


class Command(BaseCommand):
    help = (
        "Soru stem/şık/çözüm alanlarını normalize_question_for_storage ile "
        "toplu günceller (eski ham/OCR/Telegram kayıtları için)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Kaydetmeden değişecek soruları listele.",
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
            "--limit",
            type=int,
            default=0,
            help="En fazla kaç soru işlensin (0 = sınırsız).",
        )
        parser.add_argument(
            "--batch-size",
            type=int,
            default=50,
            help="bulk_update parti boyutu.",
        )
        parser.add_argument(
            "--include-unchanged",
            action="store_true",
            help="Değişmeyen soruları da listele.",
        )
        parser.add_argument(
            "--unpublished-only",
            action="store_true",
            help="Yalnızca yayınlanmamış sorular.",
        )
        parser.add_argument(
            "--published-only",
            action="store_true",
            help="Yalnızca yayınlanmış sorular.",
        )

    def handle(self, *args, **options):
        dry_run = bool(options["dry_run"])
        public_ids = options.get("public_ids") or []
        pks = options.get("pks") or []
        limit = int(options.get("limit") or 0)
        batch_size = max(1, int(options.get("batch_size") or 50))
        only_changed = not bool(options.get("include_unchanged"))
        unpublished_only = bool(options.get("unpublished_only"))
        published_only = bool(options.get("published_only"))

        qs = Question.objects.all().order_by("pk")
        if public_ids:
            qs = qs.filter(public_id__in=public_ids)
        elif pks:
            qs = qs.filter(pk__in=pks)
        if unpublished_only:
            qs = qs.filter(is_published=False)
        elif published_only:
            qs = qs.filter(is_published=True)
        if limit > 0:
            qs = qs[:limit]

        scanned = 0
        changed_count = 0
        skipped_unchanged = 0
        pending: list[Question] = []

        for question in qs.iterator():
            scanned += 1
            if only_changed and not question_needs_content_normalize(question):
                skipped_unchanged += 1
                continue

            before = snapshot_question_content(question)
            normalize_question_for_storage(question)
            changed_fields = question_content_changed(question, before=before)
            if only_changed and not changed_fields:
                skipped_unchanged += 1
                continue

            changed_count += 1
            self.stdout.write(
                f"- {question.public_id} (pk={question.pk}) "
                f"alanlar: {', '.join(changed_fields)}"
            )
            if not dry_run:
                pending.append(question)
                if len(pending) >= batch_size:
                    with transaction.atomic():
                        Question.objects.bulk_update(
                            pending, _CONTENT_UPDATE_FIELDS, batch_size=batch_size
                        )
                    pending.clear()

        if not dry_run and pending:
            with transaction.atomic():
                Question.objects.bulk_update(
                    pending, _CONTENT_UPDATE_FIELDS, batch_size=batch_size
                )

        suffix = " [dry-run]" if dry_run else ""
        self.stdout.write(
            self.style.SUCCESS(
                f"Bitti: {scanned} tarandı, {changed_count} soru "
                f"{'incelendi' if dry_run else 'güncellendi'}, "
                f"{skipped_unchanged} değişmedi{suffix}."
            )
        )
