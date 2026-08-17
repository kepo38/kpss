from django.core.management.base import BaseCommand

from content.embeddings import refresh_question_embedding
from content.models import Question


class Command(BaseCommand):
    help = "Yayınlı sorular için vektör gömme üretir / yeniler."

    def add_arguments(self, parser):
        parser.add_argument("--force", action="store_true")
        parser.add_argument("--limit", type=int, default=0)

    def handle(self, *args, **options):
        qs = Question.objects.select_related(
            "topic", "topic__subject", "scenario"
        ).order_by("id")
        if options["limit"]:
            qs = qs[: options["limit"]]
        updated = 0
        for question in qs:
            if refresh_question_embedding(question, force=options["force"]):
                updated += 1
        self.stdout.write(self.style.SUCCESS(f"{updated} soru gömüldü."))
