# Generated manually — pending solution replies for offline Telegram workflow.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0066_telegrambotsession_multi_question"),
    ]

    operations = [
        migrations.CreateModel(
            name="TelegramPendingSolution",
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
                ("telegram_user_id", models.BigIntegerField(db_index=True)),
                ("chat_id", models.BigIntegerField()),
                (
                    "photo_message_id",
                    models.BigIntegerField(
                        verbose_name="Yanıtlanan fotoğraf mesajı",
                    ),
                ),
                ("solution_text", models.TextField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={
                "verbose_name": "Telegram bekleyen çözüm",
                "verbose_name_plural": "Telegram bekleyen çözümler",
            },
        ),
        migrations.AddConstraint(
            model_name="telegrampendingsolution",
            constraint=models.UniqueConstraint(
                fields=("chat_id", "photo_message_id"),
                name="unique_telegram_pending_solution_per_photo",
            ),
        ),
    ]
