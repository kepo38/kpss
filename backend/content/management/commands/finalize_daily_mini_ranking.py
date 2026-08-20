from django.core.management.base import BaseCommand

from content.daily_mini_exam import VALID_KPSS_TYPES
from content.daily_mini_ranking import finalize_period


class Command(BaseCommand):
    help = (
        "Haftalık / aylık mini deneme sıralamasını finalize eder ve premium ödül verir. "
        "Idempotent: aynı dönem tekrar çalıştırılırsa ödül çiftlenmez."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--period",
            choices=("weekly", "monthly"),
            default="weekly",
            help="Finalize edilecek dönem türü (--auto ile yok sayılır)",
        )
        parser.add_argument(
            "--kpss-type",
            dest="kpss_type",
            default="lisans",
            choices=VALID_KPSS_TYPES,
            help="Tek KPSS tipi (--all-kpss / --auto ile yok sayılır)",
        )
        parser.add_argument(
            "--all-kpss",
            action="store_true",
            help="lisans + onLisans + ortaogretim hepsini finalize et",
        )
        parser.add_argument(
            "--auto",
            action="store_true",
            help=(
                "Cron için: haftalık + aylık, tüm KPSS tipleri. "
                "Günde bir kez (ör. 00:15 TR) çalıştırın; bitmemiş dönem atlanır, "
                "finalize edilmiş dönem tekrar ödül vermez."
            ),
        )
        parser.add_argument(
            "--no-push",
            action="store_true",
            help="FCM bildirimi gönderme",
        )

    def handle(self, *args, **options):
        send_push = not options["no_push"]
        if options["auto"]:
            periods = ("weekly", "monthly")
            kpss_types = tuple(VALID_KPSS_TYPES)
        else:
            periods = (options["period"],)
            kpss_types = (
                tuple(VALID_KPSS_TYPES)
                if options["all_kpss"]
                else (options["kpss_type"],)
            )

        any_new = False
        for period in periods:
            for kpss_type in kpss_types:
                winners = finalize_period(period, kpss_type, send_push=send_push)
                if not winners:
                    self.stdout.write(
                        self.style.WARNING(
                            f"Ödül yok / kapalı / bekliyor ({period}, {kpss_type})"
                        )
                    )
                    continue
                # finalize_period zaten finalize edilmişse mevcut kayıtları döner;
                # yalnızca yeni oluşturulmuş gibi raporla (idempotent uyarı).
                any_new = True
                for w in winners:
                    self.stdout.write(
                        self.style.SUCCESS(
                            f"{period}/{kpss_type} #{w.rank} "
                            f"user={w.user_id} +{w.premium_days}g premium"
                        )
                    )

        if options["auto"] and not any_new:
            self.stdout.write(
                self.style.NOTICE("--auto tamam: yeni ödül dağıtılmadı (normal).")
            )
