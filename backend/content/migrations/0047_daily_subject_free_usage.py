import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0046_question_view_count"),
    ]

    operations = [
        migrations.CreateModel(
            name="DailySubjectFreeUsage",
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
                    "subject_slug",
                    models.SlugField(max_length=64, verbose_name="Ders slug"),
                ),
                ("day", models.DateField(verbose_name="Gün (İstanbul)")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="daily_subject_free_usages",
                        to="content.appuser",
                        verbose_name="Öğrenci",
                    ),
                ),
            ],
            options={
                "verbose_name": "Günlük ücretsiz ders hakkı",
                "verbose_name_plural": "Günlük ücretsiz ders hakları",
            },
        ),
        migrations.AddConstraint(
            model_name="dailysubjectfreeusage",
            constraint=models.UniqueConstraint(
                fields=("user", "subject_slug", "day"),
                name="unique_daily_subject_free_usage",
            ),
        ),
        migrations.AddIndex(
            model_name="dailysubjectfreeusage",
            index=models.Index(
                fields=["user", "day"],
                name="daily_free_user_day",
            ),
        ),
    ]
