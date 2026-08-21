"""Mevcut sorularda özel test keyword etiketlerini güncelle."""

from django.core.management.base import BaseCommand

from content.models import Question
from content.special_question_tags import apply_auto_tags


class Command(BaseCommand):
    help = (
        "Yayınlı (veya --all) sorularda keyword tarayıp "
        "tag_kronoloji / tag_padisah_antlasma bayraklarını True yapar "
        "(mevcut True değerleri silmez)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Kaydetmeden kaç sorunun etiketleneceğini göster.",
        )
        parser.add_argument(
            "--all",
            action="store_true",
            help="Yalnızca yayınlı değil, tüm soruları tara.",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        qs = Question.objects.all().order_by("id")
        if not options["all"]:
            qs = qs.filter(is_published=True)

        updated = 0
        for question in qs.iterator(chunk_size=200):
            raised = apply_auto_tags(question, only_raise=True)
            if not raised:
                continue
            updated += 1
            if dry_run:
                self.stdout.write(
                    f"  would tag {question.public_id}: {', '.join(sorted(raised))}"
                )
            else:
                question.save(update_fields=sorted(raised) + ["updated_at"])

        mode = "dry-run" if dry_run else "saved"
        self.stdout.write(
            self.style.SUCCESS(f"retag_special_questions ({mode}): {updated} soru")
        )
