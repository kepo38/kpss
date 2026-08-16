from django.db import migrations, models


def backfill_hashes(apps, schema_editor):
    Question = apps.get_model("content", "Question")
    from content.question_fingerprint import (
        content_fingerprint,
        stem_fingerprint,
    )

    for q in Question.objects.all().iterator():
        q.content_hash = content_fingerprint(
            q.stem,
            q.option_a,
            q.option_b,
            q.option_c,
            q.option_d,
            q.option_e,
        )
        q.stem_hash = stem_fingerprint(q.stem)
        q.save(update_fields=["content_hash", "stem_hash"])


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0008_user_message_and_block"),
    ]

    operations = [
        migrations.AddField(
            model_name="question",
            name="content_hash",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="Normalize soru+şık SHA256 — tekrar yükleme kontrolü",
                max_length=64,
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="source_image_hash",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="OCR kaynağı görsel SHA256 (görsel saklanmasa da)",
                max_length=64,
            ),
        ),
        migrations.AddField(
            model_name="question",
            name="stem_hash",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="Normalize soru metni SHA256",
                max_length=64,
            ),
        ),
        migrations.RunPython(backfill_hashes, migrations.RunPython.noop),
    ]
