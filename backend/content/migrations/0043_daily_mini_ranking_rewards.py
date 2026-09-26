from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0042_topicsummarycard_image"),
    ]

    operations = [
        migrations.CreateModel(
            name="DailyMiniRankingCampaign",
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
                    "weekly_enabled",
                    models.BooleanField(default=True, verbose_name="Haftalık ödül aktif"),
                ),
                (
                    "monthly_enabled",
                    models.BooleanField(default=True, verbose_name="Aylık ödül aktif"),
                ),
                (
                    "rewards_visible",
                    models.BooleanField(
                        default=True,
                        verbose_name="ÖDÜL ekranı uygulamada görünsün",
                    ),
                ),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "verbose_name": "Mini deneme sıralama kampanyası",
                "verbose_name_plural": "Mini deneme sıralama kampanyası",
            },
        ),
        migrations.CreateModel(
            name="DailyMiniRankingWinner",
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
                    "period_kind",
                    models.CharField(
                        choices=[("weekly", "Haftalık"), ("monthly", "Aylık")],
                        max_length=10,
                    ),
                ),
                ("period_start", models.DateField()),
                ("period_end", models.DateField()),
                (
                    "kpss_type",
                    models.CharField(
                        choices=[
                            ("lisans", "Lisans"),
                            ("onLisans", "Ön Lisans"),
                            ("ortaogretim", "Ortaöğretim"),
                        ],
                        max_length=20,
                    ),
                ),
                ("rank", models.PositiveSmallIntegerField()),
                ("total_correct", models.PositiveIntegerField(default=0)),
                ("total_duration_seconds", models.PositiveIntegerField(default=0)),
                ("premium_days", models.PositiveSmallIntegerField(default=0)),
                ("display_name", models.CharField(blank=True, max_length=160)),
                ("email_prefix", models.CharField(blank=True, max_length=64)),
                ("email_rest", models.CharField(blank=True, max_length=120)),
                ("finalized_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="mini_ranking_wins",
                        to="content.appuser",
                    ),
                ),
            ],
            options={
                "verbose_name": "Mini deneme sıralama ödülü",
                "verbose_name_plural": "Mini deneme sıralama ödülleri",
                "ordering": ["-period_start", "rank"],
            },
        ),
        migrations.AddConstraint(
            model_name="dailyminirankingwinner",
            constraint=models.UniqueConstraint(
                fields=("period_kind", "period_start", "kpss_type", "rank"),
                name="uniq_mini_ranking_period_rank",
            ),
        ),
    ]
