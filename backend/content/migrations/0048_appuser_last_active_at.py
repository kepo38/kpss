# Generated manually for AppUser.last_active_at

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0047_daily_subject_free_usage"),
    ]

    operations = [
        migrations.AddField(
            model_name="appuser",
            name="last_active_at",
            field=models.DateTimeField(
                blank=True,
                db_index=True,
                help_text="Uygulamada API kullanıldığı son an (canlı oturum için).",
                null=True,
                verbose_name="Son aktivite",
            ),
        ),
    ]
