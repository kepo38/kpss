from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0068_telegram_pending_solution_decision"),
    ]

    operations = [
        migrations.AlterField(
            model_name="question",
            name="correct_option",
            field=models.CharField(
                blank=True,
                choices=[
                    ("", "—"),
                    ("A", "A"),
                    ("B", "B"),
                    ("C", "C"),
                    ("D", "D"),
                    ("E", "E"),
                ],
                default="",
                max_length=1,
            ),
        ),
    ]
