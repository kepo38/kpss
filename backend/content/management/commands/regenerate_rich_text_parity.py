from django.core.management.base import BaseCommand

from content.rich_text_parity import regenerate_fixture_expected


class Command(BaseCommand):
    help = "rich_text_parity.json expected alanlarını Python pipeline ile güncelle"

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Dosyaya yazmadan kaç case güncelleneceğini göster",
        )

    def handle(self, *args, **options):
        updated = regenerate_fixture_expected(dry_run=options["dry_run"])
        if options["dry_run"]:
            self.stdout.write(f"Dry run: {updated} case güncellenirdi")
        else:
            self.stdout.write(
                self.style.SUCCESS(f"{updated} case expected güncellendi")
            )
