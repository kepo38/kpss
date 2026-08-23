"""Özet kart yuvaları: boş yayınlı kartlar uygulamada yanlış sayı göstermesin."""

from django.test import TestCase

from content.models import Subject, Topic, TopicSummaryCard
from content.topic_slots import ensure_topic_summary_slots, slot_card_public_id


class SummaryCardSlotPublishTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="inkilaplar",
            name="İnkılaplar",
        )

    def test_new_slots_are_unpublished_empty(self):
        created, _ = ensure_topic_summary_slots(self.topic)
        self.assertEqual(created, 5)
        cards = TopicSummaryCard.objects.filter(topic=self.topic)
        self.assertEqual(cards.count(), 5)
        self.assertEqual(cards.filter(is_published=True).count(), 0)
        self.assertEqual(TopicSummaryCard.for_mobile_pack().count(), 0)

    def test_unpublishes_existing_empty_published_slots(self):
        for i in range(1, 6):
            TopicSummaryCard.objects.create(
                public_id=slot_card_public_id(self.topic, i),
                topic=self.topic,
                kind="tip",
                title=f"Özet {i}",
                body="",
                sort_order=i,
                is_published=True,
            )
        filled = TopicSummaryCard.objects.create(
            public_id="sum_inkilaplar_extra",
            topic=self.topic,
            kind="osym",
            title="Dolu kart",
            body="Atatürk ilke ve inkılapları...",
            sort_order=10,
            is_published=True,
        )
        self.assertEqual(
            TopicSummaryCard.objects.filter(is_published=True).count(), 6
        )
        # Paket zaten boş gövdeleri elemeli
        self.assertEqual(TopicSummaryCard.for_mobile_pack().count(), 1)

        ensure_topic_summary_slots(self.topic)

        self.assertEqual(
            TopicSummaryCard.objects.filter(is_published=True).count(), 1
        )
        self.assertEqual(TopicSummaryCard.for_mobile_pack().count(), 1)
        self.assertEqual(
            list(TopicSummaryCard.for_mobile_pack().values_list("public_id", flat=True)),
            [filled.public_id],
        )
        self.assertFalse(
            TopicSummaryCard.objects.get(
                public_id=slot_card_public_id(self.topic, 1)
            ).is_published
        )
