from datetime import date

from django.db import migrations, models


def seed_exam_types(apps, schema_editor):
    ExamType = apps.get_model("content", "ExamType")
    rows = [
        {
            "slug": "kpssLisans",
            "name": "KPSS Lisans",
            "short_name": "KPSS Lisans",
            "description": "Genel Yetenek · Genel Kültür",
            "exam_date": date(2026, 9, 6),
            "content_type": "lisans",
            "icon_key": "school",
            "sort_order": 10,
        },
        {
            "slug": "kpssOnLisans",
            "name": "KPSS Ön Lisans",
            "short_name": "Ön Lisans",
            "description": "Ön lisans KPSS oturumu",
            "exam_date": date(2026, 10, 4),
            "content_type": "onLisans",
            "icon_key": "book",
            "sort_order": 20,
        },
        {
            "slug": "kpssOrtaogretim",
            "name": "KPSS Ortaöğretim",
            "short_name": "Ortaöğretim",
            "description": "Ortaöğretim KPSS oturumu",
            "exam_date": date(2026, 10, 25),
            "content_type": "ortaogretim",
            "icon_key": "stories",
            "sort_order": 30,
        },
        {
            "slug": "ags",
            "name": "AGS",
            "short_name": "AGS",
            "description": "Akademi Giriş Sınavı",
            "exam_date": date(2026, 7, 26),
            "content_type": "lisans",
            "icon_key": "premium",
            "sort_order": 40,
        },
    ]
    for row in rows:
        ExamType.objects.update_or_create(slug=row["slug"], defaults=row)


def unseed_exam_types(apps, schema_editor):
    ExamType = apps.get_model("content", "ExamType")
    ExamType.objects.filter(
        slug__in=["kpssLisans", "kpssOnLisans", "kpssOrtaogretim", "ags"]
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0013_daily_mini_exam"),
    ]

    operations = [
        migrations.CreateModel(
            name="ExamType",
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
                (
                    "slug",
                    models.SlugField(
                        help_text="Uygulama kimliği. Örn. kpssLisans, ags, ales. Değiştirme.",
                        max_length=64,
                        unique=True,
                    ),
                ),
                ("name", models.CharField(max_length=80, verbose_name="Sınav adı")),
                (
                    "short_name",
                    models.CharField(
                        blank=True, max_length=40, verbose_name="Kısa ad"
                    ),
                ),
                (
                    "description",
                    models.CharField(
                        blank=True, max_length=160, verbose_name="Açıklama"
                    ),
                ),
                ("exam_date", models.DateField(verbose_name="Sınav tarihi")),
                (
                    "yearly_repeat",
                    models.BooleanField(
                        default=True,
                        help_text="Tarih geçtiyse sonraki yılın aynı gününü göster.",
                        verbose_name="Her yıl tekrarla",
                    ),
                ),
                (
                    "content_type",
                    models.CharField(
                        choices=[
                            ("lisans", "Lisans"),
                            ("onLisans", "Ön Lisans"),
                            ("ortaogretim", "Ortaöğretim"),
                        ],
                        default="lisans",
                        help_text="Bu sınav için hangi müfredat açılsın.",
                        max_length=20,
                        verbose_name="Soru bankası tipi",
                    ),
                ),
                (
                    "icon_key",
                    models.CharField(
                        choices=[
                            ("school", "Okul"),
                            ("book", "Kitap"),
                            ("stories", "Ders"),
                            ("premium", "Akademi"),
                            ("event", "Takvim"),
                            ("star", "Yıldız"),
                            ("balance", "Adalet"),
                            ("military", "Kamu / kurum"),
                        ],
                        default="school",
                        max_length=20,
                        verbose_name="İkon",
                    ),
                ),
                (
                    "sort_order",
                    models.PositiveIntegerField(default=0, verbose_name="Sıra"),
                ),
                ("is_active", models.BooleanField(default=True, verbose_name="Aktif")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "verbose_name": "Sınav tipi",
                "verbose_name_plural": "Sınav tipleri",
                "ordering": ["sort_order", "exam_date", "name"],
            },
        ),
        migrations.RunPython(seed_exam_types, unseed_exam_types),
    ]
