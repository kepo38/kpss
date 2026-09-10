from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0037_mobile_ui_config"),
    ]

    operations = [
        migrations.AddField(
            model_name="appuser",
            name="display_name_changed_at",
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name="Son ad değişikliği",
            ),
        ),
    ]
