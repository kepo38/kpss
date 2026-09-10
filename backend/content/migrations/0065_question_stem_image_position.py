from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0064_question_solution_image"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="stem_image_position",
            field=models.CharField(
                choices=[("above", "Üst"), ("below", "Alt")],
                default="below",
                help_text="Uygulamada görsel metnin üstünde mi altında mı gösterilsin.",
                max_length=8,
                verbose_name="Soru görseli konumu",
            ),
        ),
    ]
