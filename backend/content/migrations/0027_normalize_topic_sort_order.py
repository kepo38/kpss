from django.db import migrations


def normalize_topic_sort_order(apps, schema_editor):
    Topic = apps.get_model("content", "Topic")
    subject_ids = Topic.objects.order_by().values_list("subject_id", flat=True).distinct()
    for subject_id in subject_ids:
        for position, topic in enumerate(
            Topic.objects.filter(subject_id=subject_id).order_by(
                "sort_order", "name", "id"
            ),
            start=1,
        ):
            if topic.sort_order != position:
                Topic.objects.filter(pk=topic.pk).update(sort_order=position)


class Migration(migrations.Migration):
    dependencies = [
        ("content", "0026_maptemplate"),
    ]

    operations = [
        migrations.RunPython(
            normalize_topic_sort_order,
            migrations.RunPython.noop,
        ),
    ]
