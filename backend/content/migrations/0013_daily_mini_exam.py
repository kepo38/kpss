from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0012_appuser_premium_grant"),
    ]

    operations = [
        migrations.CreateModel(
            name="DailyMiniExam",
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
                ("exam_date", models.DateField(verbose_name="Deneme günü")),
                (
                    "kpss_type",
                    models.CharField(
                        choices=[
                            ("lisans", "Lisans"),
                            ("onLisans", "Ön Lisans"),
                            ("ortaogretim", "Ortaöğretim"),
                        ],
                        max_length=20,
                        verbose_name="KPSS tipi",
                    ),
                ),
                (
                    "question_ids",
                    models.JSONField(
                        default=list,
                        help_text="Yayınlanmış soru public_id listesi (20 adet hedef).",
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={
                "verbose_name": "Günün mini denemesi",
                "verbose_name_plural": "Günün mini denemeleri",
                "ordering": ["-exam_date", "kpss_type"],
                "unique_together": {("exam_date", "kpss_type")},
            },
        ),
        migrations.CreateModel(
            name="DailyMiniExamAttempt",
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
                ("exam_date", models.DateField(verbose_name="Deneme günü")),
                (
                    "kpss_type",
                    models.CharField(
                        choices=[
                            ("lisans", "Lisans"),
                            ("onLisans", "Ön Lisans"),
                            ("ortaogretim", "Ortaöğretim"),
                        ],
                        max_length=20,
                        verbose_name="KPSS tipi",
                    ),
                ),
                ("correct", models.PositiveSmallIntegerField(default=0)),
                ("wrong", models.PositiveSmallIntegerField(default=0)),
                ("blank", models.PositiveSmallIntegerField(default=0)),
                ("total", models.PositiveSmallIntegerField(default=20)),
                ("duration_seconds", models.PositiveIntegerField(default=0)),
                ("wrong_question_ids", models.JSONField(blank=True, default=list)),
                (
                    "answers",
                    models.JSONField(
                        blank=True, default=dict, help_text='{"q_public_id": "A"}'
                    ),
                ),
                ("completed_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="daily_mini_attempts",
                        to="content.appuser",
                        verbose_name="Kullanıcı",
                    ),
                ),
            ],
            options={
                "verbose_name": "Mini deneme sonucu",
                "verbose_name_plural": "Mini deneme sonuçları",
                "ordering": ["-correct", "duration_seconds", "completed_at"],
                "unique_together": {("user", "exam_date", "kpss_type")},
            },
        ),
        migrations.AddIndex(
            model_name="dailyminiexamattempt",
            index=models.Index(
                fields=["exam_date", "kpss_type", "-correct"],
                name="dmini_exam_rank_idx",
            ),
        ),
    ]
