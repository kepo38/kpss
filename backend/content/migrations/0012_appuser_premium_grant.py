from django.db import migrations, models
from django.utils import timezone


def grant_betuk_premium(apps, schema_editor):
    AppUser = apps.get_model("content", "AppUser")
    now = timezone.now()
    targets = {"betük", "betuk", "betül", "betul"}
    for user in AppUser.objects.all():
        name = (user.display_name or "").strip().casefold()
        email = (user.email or "").strip().casefold()
        if name in targets or any(t in name for t in ("betük", "betul")) or email.startswith("betuk") or "osymsoru@gmail.com" in email:
            user.is_premium = True
            user.premium_granted_at = now
            user.premium_grant_note = "Ücretsiz premium — admin"
            user.premium_expires_at = None
            user.save(
                update_fields=[
                    "is_premium",
                    "premium_granted_at",
                    "premium_grant_note",
                    "premium_expires_at",
                ]
            )


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0011_questionrating"),
    ]

    operations = [
        migrations.AddField(
            model_name="appuser",
            name="premium_granted_at",
            field=models.DateTimeField(
                blank=True,
                help_text="Admin tarafından ücretsiz premium tanımlandığında dolar.",
                null=True,
                verbose_name="Ücretsiz premium veriliş",
            ),
        ),
        migrations.AddField(
            model_name="appuser",
            name="premium_grant_note",
            field=models.CharField(
                blank=True,
                help_text="Örn. hediye, kampanya, destek.",
                max_length=255,
                verbose_name="Premium notu",
            ),
        ),
        migrations.RunPython(grant_betuk_premium, migrations.RunPython.noop),
    ]
