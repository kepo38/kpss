# Generated manually for premium flags on subject/topic/test.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0039_exam_pack_active_label"),
    ]

    operations = [
        migrations.AddField(
            model_name="subject",
            name="requires_premium",
            field=models.BooleanField(
                default=False,
                help_text="Açıkken bu ders premium olarak işaretlenir.",
                verbose_name="Premium",
            ),
        ),
        migrations.AddField(
            model_name="topic",
            name="requires_premium",
            field=models.BooleanField(
                default=False,
                help_text="Açıkken bu konu premium olarak işaretlenir.",
                verbose_name="Premium",
            ),
        ),
        migrations.AddField(
            model_name="topictest",
            name="requires_premium",
            field=models.BooleanField(
                default=False,
                help_text="Açıkken bu test premium olarak işaretlenir.",
                verbose_name="Premium",
            ),
        ),
    ]
