# Photo-level Evet/Hayır before OCR.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0067_telegrampendingsolution"),
    ]

    operations = [
        migrations.AlterField(
            model_name="telegrampendingsolution",
            name="solution_text",
            field=models.TextField(blank=True, default=""),
        ),
        migrations.AddField(
            model_name="telegrampendingsolution",
            name="skip_solution",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="telegrampendingsolution",
            name="awaiting_text",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="telegrampendingsolution",
            name="prompt_sent",
            field=models.BooleanField(default=False),
        ),
    ]
