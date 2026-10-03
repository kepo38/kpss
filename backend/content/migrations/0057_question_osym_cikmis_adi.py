from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0056_telegrambotsession_source_message_id"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="osym_cikmis_adi",
            field=models.CharField(
                blank=True,
                default="",
                help_text="Panel içi etiket — uygulama testlerinde gösterilmez; yalnızca ÖSYM rozeti görünür.",
                max_length=200,
                verbose_name="Çıkmış soru adı",
            ),
        ),
        migrations.CreateModel(
            name="OsymCikmisOneri",
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
                ("label", models.CharField(max_length=200, unique=True)),
                ("use_count", models.PositiveIntegerField(default=1)),
                ("last_used", models.DateTimeField(auto_now=True)),
            ],
            options={
                "verbose_name": "ÖSYM çıkmış soru önerisi",
                "verbose_name_plural": "ÖSYM çıkmış soru önerileri",
                "ordering": ["-use_count", "-last_used", "label"],
            },
        ),
    ]
