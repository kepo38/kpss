from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0048_appuser_last_active_at"),
    ]

    operations = [
        migrations.AddField(
            model_name="mobileuiconfig",
            name="banner_ads_enabled",
            field=models.BooleanField(
                default=True,
                verbose_name="Quiz banner reklamları",
            ),
        ),
    ]
