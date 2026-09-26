from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0051_mobile_ui_studio_modules"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="submission_source",
            field=models.CharField(
                blank=True,
                choices=[
                    ("", "Panel"),
                    ("telegram", "Telegram"),
                    ("panel_ocr", "Panel OCR"),
                ],
                db_index=True,
                default="",
                max_length=16,
                verbose_name="Kaynak",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="telegram_chat_id",
            field=models.BigIntegerField(
                blank=True,
                null=True,
                verbose_name="Telegram sohbet",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="telegram_message_id",
            field=models.BigIntegerField(
                blank=True,
                null=True,
                verbose_name="Telegram mesaj",
            ),
        ),
    ]
