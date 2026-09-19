from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0052_question_submission_source"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="telegram_file_unique_id",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="Aynı fotoğrafın ilet/re-send tekrarını engeller.",
                max_length=128,
                verbose_name="Telegram dosya kimliği",
            ),
        ),
    ]
