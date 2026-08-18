"""Günün mini denemesi — demo liderlik kayıtları (admin'den silinebilir)."""

from __future__ import annotations

from django.core.management.base import BaseCommand
from django.utils import timezone

from content.auth import new_api_token
from content.daily_mini_exam import VALID_KPSS_TYPES, exam_date_for, get_or_create_today_exam
from content.models import AppUser, DailyMiniExamAttempt

DEMO_PREFIX = "demo.mini"
DEMO_GOOGLE_SUB_PREFIX = "demo-mini-leader-"

DEMO_ROWS = (
    {
        "suffix": "1",
        "email": "demo.mini1@hedefkamu.app",
        "display_name": "Demo Ayşe K.",
        "correct": 18,
        "wrong": 2,
        "blank": 0,
        "duration_seconds": 612,
    },
    {
        "suffix": "2",
        "email": "demo.mini2@hedefkamu.app",
        "display_name": "Demo Mehmet Y.",
        "correct": 17,
        "wrong": 2,
        "blank": 1,
        "duration_seconds": 648,
    },
    {
        "suffix": "3",
        "email": "demo.mini3@hedefkamu.app",
        "display_name": "Demo Zeynep A.",
        "correct": 16,
        "wrong": 3,
        "blank": 1,
        "duration_seconds": 702,
    },
    {
        "suffix": "4",
        "email": "demo.mini4@hedefkamu.app",
        "display_name": "Demo Can D.",
        "correct": 15,
        "wrong": 4,
        "blank": 1,
        "duration_seconds": 735,
    },
    {
        "suffix": "5",
        "email": "demo.mini5@hedefkamu.app",
        "display_name": "Demo Elif S.",
        "correct": 14,
        "wrong": 4,
        "blank": 2,
        "duration_seconds": 780,
    },
)


class Command(BaseCommand):
    help = (
        "Günün mini denemesi için 5 demo kullanıcı ve bugünkü sıralama kaydı oluşturur. "
        "Sil: python manage.py seed_daily_mini_demo --clear"
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="demo.mini* kullanıcıları ve mini deneme sonuçlarını sil",
        )

    def handle(self, *args, **options):
        if options["clear"]:
            self._clear()
            return
        self._seed()

    def _clear(self) -> None:
        attempts = DailyMiniExamAttempt.objects.filter(
            user__email__startswith=f"{DEMO_PREFIX}"
        )
        attempt_count = attempts.count()
        attempts.delete()

        users = AppUser.objects.filter(email__startswith=f"{DEMO_PREFIX}")
        user_count = users.count()
        users.delete()

        self.stdout.write(
            self.style.SUCCESS(
                f"Demo mini deneme temizlendi: {user_count} kullanıcı, "
                f"{attempt_count} sonuç silindi."
            )
        )

    def _seed(self) -> None:
        today = exam_date_for()
        now = timezone.now()
        created_users = 0
        created_attempts = 0

        for kpss_type in VALID_KPSS_TYPES:
            get_or_create_today_exam(kpss_type)

        for row in DEMO_ROWS:
            google_sub = f"{DEMO_GOOGLE_SUB_PREFIX}{row['suffix']}"
            user, user_created = AppUser.objects.get_or_create(
                google_sub=google_sub,
                defaults={
                    "email": row["email"],
                    "display_name": row["display_name"],
                    "api_token": new_api_token(),
                    "is_anonymous": False,
                    "last_login_at": now,
                },
            )
            if user_created:
                created_users += 1
            else:
                user.email = row["email"]
                user.display_name = row["display_name"]
                user.is_active = True
                user.save(
                    update_fields=[
                        "email",
                        "display_name",
                        "is_active",
                        "updated_at",
                    ]
                )

            for kpss_type in VALID_KPSS_TYPES:
                _, attempt_created = DailyMiniExamAttempt.objects.update_or_create(
                    user=user,
                    exam_date=today,
                    kpss_type=kpss_type,
                    defaults={
                        "correct": row["correct"],
                        "wrong": row["wrong"],
                        "blank": row["blank"],
                        "total": 20,
                        "duration_seconds": row["duration_seconds"],
                        "wrong_question_ids": [],
                        "answers": {},
                        "completed_at": now,
                    },
                )
                if attempt_created:
                    created_attempts += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Demo liderlik hazır ({today.isoformat()}): "
                f"{len(DEMO_ROWS)} kullanıcı × {len(VALID_KPSS_TYPES)} KPSS tipi. "
                f"Yeni: {created_users} kullanıcı, {created_attempts} sonuç."
            )
        )
        self.stdout.write(
            "Admin > Mini deneme sonuclari / Uygulama kullanicilari "
            f"({DEMO_PREFIX}* e-postalari)."
        )
