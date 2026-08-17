import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0029_question_option_statistics"),
    ]

    operations = [
        migrations.CreateModel(
            name="QuestionScenario",
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
                    "title",
                    models.CharField(max_length=200, verbose_name="Grup başlığı"),
                ),
                ("stem", models.TextField(verbose_name="Ortak olay metni")),
                ("sort_order", models.PositiveIntegerField(default=0)),
                ("is_published", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "topic",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="question_scenarios",
                        to="content.topic",
                    ),
                ),
            ],
            options={
                "verbose_name": "Sözel mantık grubu",
                "verbose_name_plural": "Sözel mantık grupları",
                "ordering": ["sort_order", "id"],
            },
        ),
        migrations.AddField(
            model_name="question",
            name="scenario",
            field=models.ForeignKey(
                blank=True,
                help_text="Sözel mantıkta ortak olay metnini paylaşan soru grubu.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="questions",
                to="content.questionscenario",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="scenario_order",
            field=models.PositiveIntegerField(
                default=0,
                help_text="Bağlı sorunun grup içindeki sabit sırası.",
            ),
        ),
        migrations.AddIndex(
            model_name="question",
            index=models.Index(
                fields=["scenario", "scenario_order"],
                name="question_scenario_order_idx",
            ),
        ),
    ]
