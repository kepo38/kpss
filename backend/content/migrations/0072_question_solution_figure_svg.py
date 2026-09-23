from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0071_mobileuiconfig_recommended_app_version"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="solution_figure_svg",
            field=models.TextField(
                blank=True,
                help_text="Çözüm için işaretli geometri SVG’si (soru şekli + çözüm çizimleri).",
                verbose_name="Çözüm şekil kodu (SVG)",
            ),
        ),
    ]
