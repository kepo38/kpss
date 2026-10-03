from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0043_daily_mini_ranking_rewards"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="option_table",
            field=models.CharField(
                choices=[
                    ("none", "Yok"),
                    ("dual", "İkili"),
                    ("triple", "Üçlü"),
                ],
                default="none",
                help_text="Seçenekleri sütunlu göster (ikili/üçlü).",
                max_length=8,
                verbose_name="Tablo sorusu",
            ),
        ),
    ]
