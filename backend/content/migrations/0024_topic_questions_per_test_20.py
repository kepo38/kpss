from django.db import migrations, models


def bump_capacity_to_20(apps, schema_editor):
    Topic = apps.get_model("content", "Topic")
    Topic.objects.filter(questions_per_test=10).update(questions_per_test=20)


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0023_question_osym_sordu"),
    ]

    operations = [
        migrations.AlterField(
            model_name="topic",
            name="questions_per_test",
            field=models.PositiveIntegerField(default=20),
        ),
        migrations.RunPython(bump_capacity_to_20, migrations.RunPython.noop),
    ]
