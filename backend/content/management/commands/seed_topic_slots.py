from django.core.management.base import BaseCommand

from content.management.commands.seed_curriculum import CURRICULUM
from content.models import Subject, Topic
from content.topic_slots import ensure_all_topic_slots


class Command(BaseCommand):
    help = (
        "Tüm aktif konular için 5 özet kart + 5 test yuvası oluşturur. "
        "İçerik boş yuvada kalır; mobilde pasif görünür."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--skip-curriculum",
            action="store_true",
            help="Müfredatı yeniden oluşturmadan yalnızca yuvaları güncelle.",
        )
        parser.add_argument(
            "--no-migrate-legacy",
            action="store_true",
            help="Eski testlerdeki soruları Test 1'e taşıma.",
        )

    def _ensure_curriculum(self) -> None:
        keep_subject_slugs = {s["slug"] for s in CURRICULUM}
        for i, subject_data in enumerate(CURRICULUM):
            subject, _ = Subject.objects.update_or_create(
                slug=subject_data["slug"],
                defaults={
                    "name": subject_data["name"],
                    "sort_order": i,
                    "is_active": True,
                },
            )
            for j, topic_data in enumerate(subject_data["topics"]):
                Topic.objects.update_or_create(
                    subject=subject,
                    slug=topic_data["slug"],
                    defaults={
                        "name": topic_data["name"],
                        "subtopics": topic_data.get("subtopics", []),
                        "sort_order": j,
                        "is_active": True,
                        "questions_per_test": topic_data.get(
                            "questions_per_test", 20
                        ),
                    },
                )
            keep_slugs = {t["slug"] for t in subject_data["topics"]}
            subject.topics.exclude(slug__in=keep_slugs).update(is_active=False)

        Subject.objects.exclude(slug__in=keep_subject_slugs).update(
            is_active=False
        )

    def handle(self, *args, **options):
        if not options["skip_curriculum"]:
            self._ensure_curriculum()
            self.stdout.write("Müfredat kontrol edildi.")

        stats = ensure_all_topic_slots(
            migrate_legacy_tests=not options["no_migrate_legacy"],
        )
        self.stdout.write(
            self.style.SUCCESS(
                f"{stats['topics']} konu · "
                f"{stats['cards_created']} yeni kart, "
                f"{stats['cards_updated']} kart güncellendi · "
                f"{stats['tests_created']} yeni test, "
                f"{stats['tests_updated']} test güncellendi · "
                f"{stats['questions_migrated']} soru Test 1'e taşındı"
            )
        )
