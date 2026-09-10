# Generated manually for multi-photo Telegram confirmation sessions.

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0065_question_stem_image_position"),
    ]

    operations = [
        migrations.AlterField(
            model_name="telegrambotsession",
            name="telegram_user_id",
            field=models.BigIntegerField(db_index=True),
        ),
        migrations.AlterField(
            model_name="telegrambotsession",
            name="question",
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="telegram_bot_session",
                to="content.question",
            ),
        ),
    ]
