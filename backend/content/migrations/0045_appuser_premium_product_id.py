from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0044_question_option_table"),
    ]

    operations = [
        migrations.AddField(
            model_name="appuser",
            name="premium_product_id",
            field=models.CharField(
                blank=True,
                default="",
                help_text="Örn. kpss_premium_yearly / kpss_premium_monthly",
                max_length=64,
                verbose_name="Premium ürün kimliği",
            ),
        ),
    ]
