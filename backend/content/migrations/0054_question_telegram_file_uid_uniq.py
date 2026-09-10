from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0053_question_telegram_file_unique_id"),
    ]

    operations = [
        migrations.AddConstraint(
            model_name="question",
            constraint=models.UniqueConstraint(
                condition=models.Q(("telegram_file_unique_id__gt", "")),
                fields=("telegram_file_unique_id",),
                name="question_telegram_file_uid_uniq",
            ),
        ),
    ]
