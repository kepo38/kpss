from django.db import migrations, models


def seed_mobile_ui_config(apps, schema_editor):
    MobileUiConfig = apps.get_model("content", "MobileUiConfig")
    MobileUiConfig.objects.get_or_create(
        pk=1,
        defaults={
            "wrong_notebook_bubble_enabled": True,
            "wrong_notebook_bubble_label": "YANLIŞLARINI GÖR",
        },
    )


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0036_topic_test_completion"),
    ]

    operations = [
        migrations.CreateModel(
            name="MobileUiConfig",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "wrong_notebook_bubble_enabled",
                    models.BooleanField(
                        default=True,
                        verbose_name="Yanlış defteri balonu aktif",
                    ),
                ),
                (
                    "wrong_notebook_bubble_label",
                    models.CharField(
                        default="YANLIŞLARINI GÖR",
                        max_length=48,
                        verbose_name="Balon metni",
                    ),
                ),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "verbose_name": "Mobil arayüz",
                "verbose_name_plural": "Mobil arayüz",
            },
        ),
        migrations.RunPython(seed_mobile_ui_config, migrations.RunPython.noop),
    ]
