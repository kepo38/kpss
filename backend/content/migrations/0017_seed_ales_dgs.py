from datetime import date

from django.db import migrations


def seed_ales_dgs(apps, schema_editor):
    ExamType = apps.get_model("content", "ExamType")
    rows = [
        {
            "slug": "ales",
            "name": "ALES",
            "short_name": "ALES",
            "description": "Sıradaki oturum · ALES/3",
            "exam_date": date(2026, 11, 29),
            "yearly_repeat": False,
            "even_years_only": False,
            "content_type": "lisans",
            "icon_key": "star",
            "sort_order": 50,
            "is_active": True,
        },
        {
            "slug": "dgs",
            "name": "DGS",
            "short_name": "DGS",
            "description": "Dikey Geçiş Sınavı",
            "exam_date": date(2026, 7, 19),
            "yearly_repeat": False,
            "even_years_only": False,
            "content_type": "lisans",
            "icon_key": "school",
            "sort_order": 60,
            "is_active": True,
        },
    ]
    for row in rows:
        ExamType.objects.update_or_create(slug=row["slug"], defaults=row)


def unseed_ales_dgs(apps, schema_editor):
    ExamType = apps.get_model("content", "ExamType")
    ExamType.objects.filter(slug__in=["ales", "dgs"]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0016_appuser_is_anonymous"),
    ]

    operations = [
        migrations.RunPython(seed_ales_dgs, unseed_ales_dgs),
    ]
