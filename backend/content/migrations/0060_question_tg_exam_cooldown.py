from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0059_tg_exam_results_push"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="last_used_in_tg_exam_at",
            field=models.DateTimeField(
                blank=True,
                db_index=True,
                help_text="Son TG denemesinde yayınlandığı zaman.",
                null=True,
                verbose_name="Son TG deneme kullanımı",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="tg_exam_cooldown_counter",
            field=models.PositiveSmallIntegerField(
                db_index=True,
                default=0,
                help_text="Son kullanımdan bu yana yayınlanan TG deneme sayısı. "
                "4 ve üzeri → kolay/orta soru tekrar seçilebilir.",
                verbose_name="TG deneme cooldown",
            ),
        ),
        migrations.AddField(
            model_name="tgexam",
            name="tg_usage_recorded",
            field=models.BooleanField(
                default=False,
                help_text="Yayınlandığında soru cooldown metadatası bir kez işlendi.",
                verbose_name="Soru kullanımı kaydedildi",
            ),
        ),
    ]
