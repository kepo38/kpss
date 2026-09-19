from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0050_question_special_test_tags"),
    ]

    operations = [
        migrations.AddField(
            model_name="mobileuiconfig",
            name="studio_modules",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text="Stüdyo modül anahtarları → aktif (true/false). Boş = hepsi açık.",
                verbose_name="Stüdyo modülleri",
            ),
        ),
    ]
