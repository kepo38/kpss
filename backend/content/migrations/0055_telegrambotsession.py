from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0054_question_telegram_file_uid_uniq"),
    ]

    operations = [
        migrations.CreateModel(
            name="TelegramBotSession",
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
                ("telegram_user_id", models.BigIntegerField(db_index=True, unique=True)),
                ("chat_id", models.BigIntegerField()),
                (
                    "step",
                    models.CharField(
                        choices=[
                            ("solution_yes_no", "Çözüm evet/hayır"),
                            ("solution_text", "Çözüm metni bekleniyor"),
                        ],
                        max_length=32,
                    ),
                ),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "question",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="telegram_bot_sessions",
                        to="content.question",
                    ),
                ),
            ],
            options={
                "verbose_name": "Telegram bot oturumu",
                "verbose_name_plural": "Telegram bot oturumları",
            },
        ),
    ]
