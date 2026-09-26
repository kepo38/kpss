from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0060_question_tg_exam_cooldown"),
    ]

    operations = [
        migrations.AddField(
            model_name="tgexam",
            name="announcement_push_sent_at",
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name="Duyuru bildirimi gönderildi",
            ),
        ),
        migrations.AddField(
            model_name="tgexam",
            name="announcement_push_success_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="tgexam",
            name="announcement_push_fail_count",
            field=models.PositiveIntegerField(default=0),
        ),
    ]
