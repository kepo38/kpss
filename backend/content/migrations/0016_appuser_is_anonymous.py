from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0015_exam_type_even_years"),
    ]

    operations = [
        migrations.AddField(
            model_name="appuser",
            name="is_anonymous",
            field=models.BooleanField(
                default=False,
                verbose_name="Anonim hesap",
                help_text="Firebase anonim oturum; Google ile bağlanınca kapanır.",
            ),
        ),
    ]
