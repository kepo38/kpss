from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0006_app_user"),
    ]

    operations = [
        migrations.AlterField(
            model_name="announcement",
            name="body",
            field=models.TextField(blank=True, verbose_name="Metin"),
        ),
        migrations.AddField(
            model_name="announcement",
            name="image",
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to="announcements/%Y/%m/",
                verbose_name="Fotoğraf",
            ),
        ),
    ]
