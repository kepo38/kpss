from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0030_questionscenario_question_scenario"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="embedding",
            field=models.JSONField(
                blank=True,
                default=list,
                help_text="Soru metninin vektör gömülmesi (anlamsal benzerlik).",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="embedding_hash",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="Gömme üretildiğindeki metin parmak izi.",
                max_length=64,
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="embedding_model",
            field=models.CharField(blank=True, default="", max_length=80),
        ),
    ]
