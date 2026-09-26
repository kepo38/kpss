from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0055_telegrambotsession"),
    ]

    operations = [
        migrations.AddField(
            model_name="telegrambotsession",
            name="source_message_id",
            field=models.BigIntegerField(
                blank=True,
                help_text="evet denince silinir; hayır denince sohbette kalır",
                null=True,
                verbose_name="Telegram fotoğraf mesajı",
            ),
        ),
    ]
