from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0069_question_correct_option_blank"),
    ]

    operations = [
        migrations.AddField(
            model_name="ocringestlog",
            name="diagnostics",
            field=models.JSONField(blank=True, default=dict),
        ),
    ]
