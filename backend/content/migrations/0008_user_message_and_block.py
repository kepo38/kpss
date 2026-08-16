from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0007_announcement_image"),
    ]

    operations = [
        migrations.AddField(
            model_name="appuser",
            name="block_reason",
            field=models.CharField(
                blank=True, max_length=255, verbose_name="Engel gerekçesi"
            ),
        ),
        migrations.AlterField(
            model_name="appuser",
            name="is_active",
            field=models.BooleanField(
                default=True,
                help_text="Kapalıysa kullanıcı engellenmiştir; giriş yapamaz.",
                verbose_name="Aktif",
            ),
        ),
        migrations.CreateModel(
            name="UserMessage",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("title", models.CharField(max_length=160, verbose_name="Başlık")),
                ("body", models.TextField(verbose_name="Metin")),
                (
                    "is_read",
                    models.BooleanField(default=False, verbose_name="Okundu"),
                ),
                (
                    "push_sent_at",
                    models.DateTimeField(
                        blank=True, null=True, verbose_name="Bildirim gönderildi"
                    ),
                ),
                ("push_success_count", models.PositiveIntegerField(default=0)),
                ("push_fail_count", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="messages",
                        to="content.appuser",
                        verbose_name="Kullanıcı",
                    ),
                ),
            ],
            options={
                "verbose_name": "Kullanıcı mesajı",
                "verbose_name_plural": "Kullanıcı mesajları",
                "ordering": ["-created_at"],
            },
        ),
    ]
