"""public_id ile soru teşhisi — risk skoru, C1/C2/C3/H1, kalıcı PNG."""

from __future__ import annotations

from django.core.management.base import BaseCommand

from content.question_diagnosis import diagnose_question_public_id


class Command(BaseCommand):
    help = (
        "Bozuk soru teşhisi: public_id yapıştır → risk skoru, C1/C2/C3/H1, "
        "kalıcı PNG envanteri."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "public_id",
            nargs="?",
            default="",
            help="Soru public_id (örn. q_abc123)",
        )

    def handle(self, *args, **options):
        public_id = (options.get("public_id") or "").strip()
        if not public_id:
            self.stderr.write(
                self.style.ERROR("public_id gerekli: manage.py diagnose_question q_...")
            )
            return

        diag = diagnose_question_public_id(public_id)
        if not diag.found:
            self.stdout.write(self.style.WARNING("KAYIT YOK"))
            for line in diag.summary_lines:
                self.stdout.write(f"  {line}")
            self.stdout.write("")
            self.stdout.write(
                "Sonraki adım: /panel/onay-bekleyen-sorular/ (risk skoru) "
                "veya OcrIngestLog — C2/C3 öncelikli."
            )
            return

        self.stdout.write(self.style.SUCCESS("KAYIT VAR"))
        if diag.priority_codes:
            self.stdout.write(
                self.style.HTTP_INFO(f"Sinif onceligi: {' > '.join(diag.priority_codes)}")
            )
        for line in diag.summary_lines:
            self.stdout.write(f"  {line}")
        if diag.panel_edit_path:
            self.stdout.write("")
            self.stdout.write(f"Panel: {diag.panel_edit_path}")
