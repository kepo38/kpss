"""Her konu için 5 özet kart + 5 test yuvası oluşturur."""

from __future__ import annotations

from content.models import Topic, TopicSummaryCard, TopicTest

SLOTS_PER_TOPIC = 5

CARD_KINDS = ("tip", "formula", "osym", "tip", "formula")

CARD_KIND_LABELS = {
    "tip": "Püf nokta",
    "formula": "Formül",
    "osym": "ÖSYM buradan sorar",
}


def slot_test_public_id(topic: Topic, index: int) -> str:
    return f"test_{topic.slug}_{index}"


def slot_card_public_id(topic: Topic, index: int) -> str:
    return f"sum_{topic.slug}_{index}"


def ensure_topic_summary_slots(topic: Topic) -> tuple[int, int]:
    """5 özet kart yuvası; gövde doluysa dokunma."""
    created = updated = 0
    for i in range(1, SLOTS_PER_TOPIC + 1):
        kind = CARD_KINDS[i - 1]
        label = CARD_KIND_LABELS[kind]
        public_id = slot_card_public_id(topic, i)
        existing = TopicSummaryCard.objects.filter(public_id=public_id).first()
        defaults = {
            "topic": topic,
            "kind": kind,
            "title": f"Özet {i} · {label}",
            "sort_order": i,
            "is_published": True,
        }
        if existing is None:
            TopicSummaryCard.objects.create(
                public_id=public_id,
                body="",
                **defaults,
            )
            created += 1
        else:
            changed = False
            for field, value in defaults.items():
                if getattr(existing, field) != value:
                    setattr(existing, field, value)
                    changed = True
            if not existing.is_published:
                existing.is_published = True
                changed = True
            if changed:
                existing.save()
                updated += 1
    return created, updated


def _migrate_legacy_test_questions(topic: Topic, slot_tests: list[TopicTest]) -> int:
    """Yuvaya bağlı olmayan eski testlerdeki soruları Test 1'e taşır."""
    if not slot_tests:
        return 0
    slot_ids = {t.public_id for t in slot_tests}
    legacy = topic.tests.exclude(public_id__in=slot_ids)
    moved = 0
    primary = slot_tests[0]
    for old in legacy:
        qs = list(old.questions.filter(topic=topic))
        if qs:
            primary.questions.add(*qs)
            moved += len(qs)
        old.is_published = False
        old.save(update_fields=["is_published", "updated_at"])
        # Sorular taşındıysa eski kaydı sil; boş yuvaları da temizle
        old.questions.clear()
        old.delete()
    if moved and not primary.is_published:
        primary.is_published = True
        primary.save(update_fields=["is_published", "updated_at"])
    return moved


def ensure_topic_test_slots(topic: Topic, *, migrate_legacy: bool = True) -> tuple[int, int, int]:
    """5 test yuvası (Test 1…5); soru yoksa yine de yayınlı. Çift başlık birleştirilir."""
    from .test_grouping import merge_duplicate_titled_tests

    # Önce aynı başlıklı çiftleri birleştir (YAYINDA+TASLAK Test 1 vb.)
    merge_duplicate_titled_tests(topic)

    created = updated = 0
    slot_tests: list[TopicTest] = []
    for i in range(1, SLOTS_PER_TOPIC + 1):
        public_id = slot_test_public_id(topic, i)
        title = f"Test {i}"
        existing = TopicTest.objects.filter(public_id=public_id).first()
        if existing is None:
            # Aynı başlıklı eski kaydı yuvaya dönüştür
            by_title = (
                topic.tests.filter(title__iexact=title)
                .order_by("-is_published", "id")
                .first()
            )
            if by_title is not None and by_title.public_id not in {
                slot_test_public_id(topic, j) for j in range(1, SLOTS_PER_TOPIC + 1)
            }:
                by_title.public_id = public_id
                by_title.title = title
                by_title.is_published = True
                by_title.save(
                    update_fields=["public_id", "title", "is_published", "updated_at"]
                )
                existing = by_title
                updated += 1

        defaults = {
            "topic": topic,
            "title": title,
            "description": "",
            "time_limit_minutes": 0,
            "is_published": True,
        }
        if existing is None:
            test = TopicTest.objects.create(public_id=public_id, **defaults)
            created += 1
        else:
            test = existing
            changed = False
            for field, value in defaults.items():
                if getattr(test, field) != value:
                    setattr(test, field, value)
                    changed = True
            if changed:
                test.save()
                updated += 1
        slot_tests.append(test)

    moved = 0
    if migrate_legacy:
        moved = _migrate_legacy_test_questions(topic, slot_tests)

    # Kalan çift başlıkları tekrar temizle
    merge_duplicate_titled_tests(topic)

    return created, updated, moved


def ensure_all_topic_slots(
    *,
    migrate_legacy_tests: bool = True,
    only_active: bool = True,
) -> dict[str, int]:
    qs = Topic.objects.select_related("subject")
    if only_active:
        qs = qs.filter(is_active=True, subject__is_active=True)

    stats = {
        "topics": 0,
        "cards_created": 0,
        "cards_updated": 0,
        "tests_created": 0,
        "tests_updated": 0,
        "questions_migrated": 0,
    }
    for topic in qs.order_by("subject__sort_order", "sort_order", "id"):
        stats["topics"] += 1
        c_created, c_updated = ensure_topic_summary_slots(topic)
        stats["cards_created"] += c_created
        stats["cards_updated"] += c_updated
        t_created, t_updated, moved = ensure_topic_test_slots(
            topic, migrate_legacy=migrate_legacy_tests
        )
        stats["tests_created"] += t_created
        stats["tests_updated"] += t_updated
        stats["questions_migrated"] += moved
    return stats
