from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0070_ocringestlog_diagnostics"),
    ]

    operations = [
        migrations.AddField(
            model_name="mobileuiconfig",
            name="recommended_app_version",
            field=models.CharField(
                blank=True,
                default="",
                help_text="Boş bırakılırsa güncelleme uyarısı gösterilmez. Örn: 1.0.2",
                max_length=32,
                verbose_name="Önerilen uygulama sürümü",
            ),
        ),
    ]
