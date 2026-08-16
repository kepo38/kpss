from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0022_alter_examtype_and_question_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="osym_sordu",
            field=models.BooleanField(
                default=False,
                help_text="İşaretlenirse uygulamada sorunun sağ üstünde ÖSYM rozeti görünür.",
                verbose_name="ÖSYM sordu",
            ),
        ),
    ]
