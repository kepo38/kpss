from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0058_tg_exam"),
    ]

    operations = [
        migrations.AddField(
            model_name="tgexam",
            name="results_published_at",
            field=models.DateTimeField(
                blank=True, null=True, verbose_name="Sonuç yayın zamanı"
            ),
        ),
        migrations.AddField(
            model_name="tgexam",
            name="results_push_sent_at",
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name="Sonuç bildirimi gönderildi",
            ),
        ),
        migrations.AddField(
            model_name="tgexam",
            name="results_push_success_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="tgexam",
            name="results_push_fail_count",
            field=models.PositiveIntegerField(default=0),
        ),
    ]
