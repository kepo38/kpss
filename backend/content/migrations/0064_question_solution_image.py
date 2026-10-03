from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0063_question_option_images"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="solution_image",
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to="question_solutions/%Y/%m/",
                verbose_name="Çözüm görseli",
            ),
        ),
    ]
