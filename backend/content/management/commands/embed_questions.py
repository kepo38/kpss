from django.core.management.base import BaseCommand

from content.embeddings import embed_texts, embedding_text_for, text_hash
from content.models import Question


class Command(BaseCommand):
    help = "Yayınlı sorular için vektör gömme üretir / yeniler."

    def add_arguments(self, parser):
        parser.add_argument("--force", action="store_true")
        parser.add_argument("--limit", type=int, default=0)
        parser.add_argument("--batch-size", type=int, default=100)

    def handle(self, *args, **options):
        force = bool(options["force"])
        batch_size = max(1, int(options["batch_size"] or 100))
        qs = Question.objects.select_related(
            "topic", "topic__subject", "scenario"
        ).order_by("id")
        if options["limit"]:
            qs = qs[: options["limit"]]
        questions = list(qs)
        updated = 0
        skipped = 0
        failed = 0

        for i in range(0, len(questions), batch_size):
            chunk = questions[i : i + batch_size]
            pending: list[Question] = []
            pending_texts: list[str] = []
            pending_hashes: list[str] = []

            for question in chunk:
                text = embedding_text_for(question)
                digest = text_hash(text)
                if (
                    not force
                    and question.embedding
                    and question.embedding_hash == digest
                ):
                    skipped += 1
                    continue
                pending.append(question)
                pending_texts.append(text)
                pending_hashes.append(digest)

            if not pending:
                continue

            try:
                vectors, model = embed_texts(pending_texts)
            except Exception as exc:  # noqa: BLE001
                self.stdout.write(
                    self.style.WARNING(
                        f"Batch {i // batch_size + 1} başarısız: {exc}"
                    )
                )
                failed += len(pending)
                continue

            for question, vector, digest in zip(pending, vectors, pending_hashes):
                try:
                    question.embedding = vector
                    question.embedding_model = model
                    question.embedding_hash = digest
                    question.save(
                        update_fields=["embedding", "embedding_model", "embedding_hash"]
                    )
                    updated += 1
                except Exception:  # noqa: BLE001
                    failed += 1

            self.stdout.write(
                f"İlerleme: {min(i + batch_size, len(questions))}/{len(questions)}"
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"Güncellendi: {updated}, Atlandı: {skipped}, Hata: {failed}"
            )
        )
