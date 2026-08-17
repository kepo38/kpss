from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0024_topic_questions_per_test_20"),
    ]

    operations = [
        migrations.CreateModel(
            name="QuestionErrorReport",
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
                    "category",
                    models.CharField(
                        choices=[
                            ("wrong_answer", "Cevap anahtarı yanlış"),
                            ("outdated", "Soru güncel değil"),
                            ("typo", "Yazım / ifade hatası"),
                            ("missing_content", "Eksik görsel / şekil"),
                            ("other", "Diğer"),
                        ],
                        max_length=32,
                        verbose_name="Bildirim türü",
                    ),
                ),
                ("note", models.TextField(blank=True, verbose_name="Not")),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("open", "İncelenecek"),
                            ("reviewed", "İncelendi"),
                            ("resolved", "Çözüldü"),
                            ("dismissed", "Reddedildi"),
                        ],
                        default="open",
                        max_length=16,
                        verbose_name="Durum",
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(auto_now_add=True, verbose_name="Bildirildi"),
                ),
                (
                    "updated_at",
                    models.DateTimeField(auto_now=True, verbose_name="Güncelleme"),
                ),
                (
                    "question",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="error_reports",
                        to="content.question",
                        verbose_name="Soru",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="question_error_reports",
                        to="content.appuser",
                        verbose_name="Öğrenci",
                    ),
                ),
            ],
            options={
                "verbose_name": "Soru hata bildirimi",
                "verbose_name_plural": "Soru hata bildirimleri",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="questionerrorreport",
            index=models.Index(
                fields=["status", "-created_at"], name="qerr_status_created"
            ),
        ),
        migrations.AddIndex(
            model_name="questionerrorreport",
            index=models.Index(
                fields=["question", "status"], name="qerr_question_status"
            ),
        ),
        migrations.AddConstraint(
            model_name="questionerrorreport",
            constraint=models.UniqueConstraint(
                fields=("question", "user"),
                name="unique_question_error_report_per_user",
            ),
        ),
    ]
