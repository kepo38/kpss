from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0041_topic_summary_card"),
    ]

    operations = [
        migrations.AddField(
            model_name="topicsummarycard",
            name="image",
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to="summary_cards/%Y/%m/",
                verbose_name="Görsel",
            ),
        ),
    ]
