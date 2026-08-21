from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0049_mobileuiconfig_banner_ads_enabled"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="tag_kronoloji",
            field=models.BooleanField(
                db_index=True,
                default=False,
                help_text="Tarih Kronoloji özel test havuzuna dahil edilir.",
                verbose_name="Özel test: Kronoloji",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="tag_padisah_antlasma",
            field=models.BooleanField(
                db_index=True,
                default=False,
                help_text="Padişahlar ve Antlaşmalar özel test havuzuna dahil edilir.",
                verbose_name="Özel test: Padişahlar ve Antlaşmalar",
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="tag_celdirici",
            field=models.BooleanField(
                db_index=True,
                default=False,
                help_text="Çeldiricisi güçlü / tuzak soru özel test havuzuna dahil edilir.",
                verbose_name="Özel test: Çeldiricisi güçlü",
            ),
        ),
    ]
