from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

DEFAULT_USERNAME = "admin"
DEFAULT_PASSWORD = "admin"
DEFAULT_EMAIL = "admin@kpssodak.local"


class Command(BaseCommand):
    help = "Varsayılan admin kullanıcısını oluşturur veya şifresini günceller."

    def handle(self, *args, **options):
        user_model = get_user_model()
        user, created = user_model.objects.get_or_create(
            username=DEFAULT_USERNAME,
            defaults={
                "email": DEFAULT_EMAIL,
                "is_staff": True,
                "is_superuser": True,
            },
        )
        if not created:
            user.is_staff = True
            user.is_superuser = True
            if not user.email:
                user.email = DEFAULT_EMAIL

        user.set_password(DEFAULT_PASSWORD)
        user.save()

        action = "oluşturuldu" if created else "güncellendi"
        self.stdout.write(
            self.style.SUCCESS(
                f"Admin kullanıcı {action}: {DEFAULT_USERNAME} / {DEFAULT_PASSWORD}"
            )
        )
