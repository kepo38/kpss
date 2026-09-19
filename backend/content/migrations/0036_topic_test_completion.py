from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0035_exam_packs"),
    ]

    operations = [
        migrations.CreateModel(
            name="TopicTestCompletion",
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
                ("completed_at", models.DateTimeField(auto_now_add=True)),
                (
                    "topic_test",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="completions",
                        to="content.topictest",
                        verbose_name="Konu testi",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="topic_test_completions",
                        to="content.appuser",
                        verbose_name="Öğrenci",
                    ),
                ),
            ],
            options={
                "verbose_name": "Konu testi tamamlama",
                "verbose_name_plural": "Konu testi tamamlamaları",
            },
        ),
        migrations.AddConstraint(
            model_name="topictestcompletion",
            constraint=models.UniqueConstraint(
                fields=("user", "topic_test"),
                name="unique_topic_test_completion_per_user",
            ),
        ),
    ]
