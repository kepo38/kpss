from django.db import migrations


def correct_ales_dgs_schedule(apps, schema_editor):
    ExamType = apps.get_model("content", "ExamType")
    ExamType.objects.filter(slug__in=["ales", "dgs"]).update(
        yearly_repeat=False,
        even_years_only=False,
    )
    ExamType.objects.filter(slug="ales").update(
        description="Sıradaki oturum · ALES/3",
    )


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0017_seed_ales_dgs"),
    ]

    operations = [
        migrations.RunPython(
            correct_ales_dgs_schedule,
            migrations.RunPython.noop,
        ),
    ]
