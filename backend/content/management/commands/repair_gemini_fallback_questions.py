"""Tesseract fallback ile kalan Telegram sorularını Gemini ile onar."""

from __future__ import annotations

from django.core.management.base import BaseCommand

from content.models import Question
from content.ocr_ingest import repair_question_with_gemini


class Command(BaseCommand):
    help = (
        "Kaynak görseli olan, yayınlanmamış Telegram sorularında Gemini OCR ile "
        "cevap/çözüm/metin alanlarını yeniler (Tesseract fallback sonrası)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--pk",
            type=int,
            action="append",
            dest="pks",
            help="Yalnızca belirtilen soru pk (tekrarlanabilir).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Kaydetmeden ne değişeceğini göster.",
        )
        parser.add_argument(
            "--all-telegram-pending",
            action="store_true",
            help="Yayınlanmamış tüm Telegram sorularını tara.",
        )

    def handle(self, *args, **options):
        dry_run = bool(options["dry_run"])
        pks = options.get("pks") or []
        all_pending = bool(options["all_telegram_pending"])

        if pks:
            qs = Question.objects.filter(pk__in=pks).order_by("pk")
        elif all_pending:
            qs = (
                Question.objects.filter(
                    submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                    is_published=False,
                )
                .exclude(image="")
                .order_by("pk")
            )
        else:
            qs = (
                Question.objects.filter(
                    submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                    is_published=False,
                    solution="",
                )
                .filter(correct_option__in=["", "A"])
                .exclude(image="")
                .order_by("pk")
            )

        if not qs.exists():
            self.stdout.write("Onarılacak soru bulunamadı.")
            return

        ok_count = 0
        fail_count = 0
        for question in qs:
            result = repair_question_with_gemini(question, dry_run=dry_run)
            if result.get("ok"):
                ok_count += 1
                updates = result.get("updates") or {}
                self.stdout.write(
                    self.style.SUCCESS(
                        f"OK pk={result['pk']} {result.get('public_id')} "
                        f"engine={result.get('engine')} "
                        f"correct={updates.get('correct_option', '-')} "
                        f"solution_len={len(updates.get('solution', ''))}"
                        + (" [dry-run]" if dry_run else "")
                    )
                )
            else:
                fail_count += 1
                self.stdout.write(
                    self.style.ERROR(
                        f"FAIL pk={result.get('pk')} "
                        f"{result.get('public_id', '')}: {result.get('error')}"
                    )
                )

        self.stdout.write(
            f"Bitti: {ok_count} başarılı, {fail_count} hata "
            f"(toplam {qs.count()} soru)."
        )
