from django.core.management.base import BaseCommand

from content.tg_exam import (
    dispatch_due_tg_exam_announcements,
    finalize_due_tg_exams,
)


class Command(BaseCommand):
    help = (
        "TG denemeleri: başlangıçtan 2 saat önce duyuru FCM, bitişte sonuç yayını. Idempotent."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--no-push",
            action="store_true",
            help="FCM bildirimi gönderme",
        )

    def handle(self, *args, **options):
        send_push = not options["no_push"]
        announced = dispatch_due_tg_exam_announcements(send_push=send_push)
        for exam_id in announced:
            self.stdout.write(
                self.style.SUCCESS(
                    f"TG deneme #{exam_id} duyuru bildirimi gönderildi."
                )
            )
        published = finalize_due_tg_exams(send_push=send_push)
        for exam_id in published:
            self.stdout.write(
                self.style.SUCCESS(f"TG deneme #{exam_id} sonuçları yayınlandı.")
            )
        if not announced and not published:
            self.stdout.write(self.style.WARNING("İşlenecek TG denemesi yok."))
