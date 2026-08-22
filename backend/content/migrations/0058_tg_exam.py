from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0057_question_osym_cikmis_adi"),
    ]

    operations = [
        migrations.CreateModel(
            name="TgExam",
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
                ("title", models.CharField(max_length=200, verbose_name="Deneme adı")),
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
                ("start_at", models.DateTimeField(verbose_name="Başlangıç")),
                ("end_at", models.DateTimeField(verbose_name="Bitiş")),
                (
                    "duration_minutes",
                    models.PositiveIntegerField(
                        default=120, verbose_name="Süre (dk)"
                    ),
                ),
                (
                    "question_ids",
                    models.JSONField(
                        blank=True,
                        default=list,
                        help_text="Yayınlanmış soru public_id listesi (sıralı).",
                    ),
                ),
                (
                    "is_results_published",
                    models.BooleanField(
                        default=False, verbose_name="Sonuçlar açıklandı"
                    ),
                ),
                (
                    "is_published",
                    models.BooleanField(
                        default=False,
                        help_text="Kapalıysa mobil listede görünmez.",
                        verbose_name="Yayında",
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "verbose_name": "TG denemesi",
                "verbose_name_plural": "TG denemeleri",
                "ordering": ["-start_at"],
            },
        ),
        migrations.CreateModel(
            name="TgExamAttempt",
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
                    "answers",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text='{"q_public_id": "A"}',
                    ),
                ),
                ("current_index", models.PositiveIntegerField(default=0)),
                ("elapsed_seconds", models.PositiveIntegerField(default=0)),
                ("correct", models.PositiveSmallIntegerField(default=0)),
                ("wrong", models.PositiveSmallIntegerField(default=0)),
                ("blank", models.PositiveSmallIntegerField(default=0)),
                (
                    "net",
                    models.DecimalField(decimal_places=2, default=0, max_digits=6),
                ),
                (
                    "subject_nets",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text='{"tarih": 12.5, "cografya": 8.25}',
                    ),
                ),
                (
                    "ranking",
                    models.PositiveIntegerField(
                        blank=True, null=True, verbose_name="Sıralama"
                    ),
                ),
                ("duration_seconds", models.PositiveIntegerField(default=0)),
                (
                    "is_submitted",
                    models.BooleanField(default=False, verbose_name="Gönderildi"),
                ),
                ("started_at", models.DateTimeField(auto_now_add=True)),
                ("submitted_at", models.DateTimeField(blank=True, null=True)),
                (
                    "exam",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="attempts",
                        to="content.tgexam",
                        verbose_name="Deneme",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="tg_exam_attempts",
                        to="content.appuser",
                        verbose_name="Kullanıcı",
                    ),
                ),
            ],
            options={
                "verbose_name": "TG deneme sonucu",
                "verbose_name_plural": "TG deneme sonuçları",
                "ordering": ["-submitted_at", "-started_at"],
            },
        ),
        migrations.AddIndex(
            model_name="tgexamattempt",
            index=models.Index(
                fields=["exam", "-net", "duration_seconds"],
                name="tg_exam_rank_idx",
            ),
        ),
        migrations.AlterUniqueTogether(
            name="tgexamattempt",
            unique_together={("user", "exam")},
        ),
    ]
