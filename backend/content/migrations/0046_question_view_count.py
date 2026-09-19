from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0045_appuser_premium_product_id"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="view_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.CreateModel(
            name="QuestionView",
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
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "question",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="views",
                        to="content.question",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="question_views",
                        to="content.appuser",
                    ),
                ),
            ],
            options={
                "verbose_name": "Soru görüntüleme",
                "verbose_name_plural": "Soru görüntülemeleri",
                "unique_together": {("user", "question")},
            },
        ),
    ]
