from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0009_question_fingerprints"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="map_markers",
            field=models.JSONField(
                blank=True,
                default=list,
                help_text="Yüzde koordinatlı harita işaretleri.",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="map_template",
            field=models.CharField(
                blank=True,
                choices=[
                    ("", "Harita yok"),
                    ("turkiye_goller", "Türkiye — Tuz Gölü ve Van Gölü"),
                ],
                default="",
                help_text="Koordinatlı harita sorusu şablonu.",
                max_length=32,
            ),
        ),
    ]
