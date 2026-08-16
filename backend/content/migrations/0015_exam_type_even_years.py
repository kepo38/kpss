from django.db import migrations, models


def mark_even_year_exams(apps, schema_editor):
    ExamType = apps.get_model("content", "ExamType")
    ExamType.objects.filter(slug__in=["kpssOnLisans", "kpssOrtaogretim"]).update(
        even_years_only=True
    )


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0014_exam_type"),
    ]

    operations = [
        migrations.AddField(
            model_name="examtype",
            name="even_years_only",
            field=models.BooleanField(
                default=False,
                help_text="Ön Lisans ve Ortaöğretim KPSS: tek yıllarda sınav olmaz, sayaç 2 yıl atlar.",
                verbose_name="Yalnızca çift yıllar",
            ),
        ),
        migrations.RunPython(mark_even_year_exams, migrations.RunPython.noop),
    ]
