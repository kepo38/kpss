from django.test import TestCase

from content.models import Question, Subject, Topic, TopicTest
from content.test_grouping import (
    assign_question_to_test,
    create_topic_test,
    get_open_or_create_test,
    next_test_number,
    topic_test_capacity,
)


class TestGroupingUnitTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(
            slug="t_grp", name="Test Ders", sort_order=1
        )
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="t_konu",
            name="Test Konu",
            questions_per_test=2,
        )

    def _q(self, i: int) -> Question:
        return Question.objects.create(
            topic=self.topic,
            public_id=f"q_grp_{i}",
            stem=f"Soru {i}",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )

    def test_capacity(self):
        self.assertEqual(topic_test_capacity(self.topic), 2)

    def test_fills_then_creates_next(self):
        t1, created = get_open_or_create_test(self.topic)
        self.assertTrue(created)
        self.assertEqual(t1.title, "Test 1")

        q1 = self._q(1)
        assign_question_to_test(q1, self.topic, "auto")
        self.assertEqual(t1.questions.count(), 1)

        q2 = self._q(2)
        assign_question_to_test(q2, self.topic, str(t1.id))
        self.assertEqual(t1.questions.count(), 2)

        t2, created2 = get_open_or_create_test(self.topic)
        self.assertTrue(created2)
        self.assertEqual(t2.title, "Test 2")

        q3 = self._q(3)
        dest = assign_question_to_test(q3, self.topic, "auto")
        self.assertEqual(dest.id, t2.id)
        self.assertEqual(t2.questions.count(), 1)

    def test_fills_earliest_slot_when_five_precreated(self):
        from content.topic_slots import ensure_topic_test_slots

        ensure_topic_test_slots(self.topic, migrate_legacy=False)
        titles = list(
            self.topic.tests.order_by("created_at", "id").values_list(
                "title", flat=True
            )
        )
        self.assertEqual(titles, ["Test 1", "Test 2", "Test 3", "Test 4", "Test 5"])

        dest = assign_question_to_test(self._q(1), self.topic, "auto")
        self.assertEqual(dest.title, "Test 1")
        self.assertEqual(dest.questions.count(), 1)

        # Test 1 kapasitesi 2; ikinci soru da Test 1'e
        dest2 = assign_question_to_test(self._q(2), self.topic, "auto")
        self.assertEqual(dest2.title, "Test 1")
        self.assertEqual(dest2.questions.count(), 2)

        # Test 1 dolunca Test 2
        dest3 = assign_question_to_test(self._q(3), self.topic, "auto")
        self.assertEqual(dest3.title, "Test 2")
        self.assertEqual(dest3.questions.count(), 1)

    def test_merge_duplicate_titled_tests(self):
        from content.test_grouping import merge_duplicate_titled_tests
        from content.topic_slots import ensure_topic_test_slots, slot_test_public_id

        ensure_topic_test_slots(self.topic, migrate_legacy=False)
        slot = TopicTest.objects.get(public_id=slot_test_public_id(self.topic, 1))
        legacy = TopicTest.objects.create(
            topic=self.topic,
            public_id="test_legacy_dup",
            title="Test 1",
            is_published=False,
        )
        q1, q2, q3 = self._q(1), self._q(2), self._q(3)
        slot.questions.set([q1, q2])
        legacy.questions.set([q2, q3])

        summary = merge_duplicate_titled_tests(self.topic)
        self.assertEqual(summary["merged_groups"], 1)
        self.assertEqual(summary["removed"], 1)
        self.assertFalse(
            TopicTest.objects.filter(public_id="test_legacy_dup").exists()
        )
        slot.refresh_from_db()
        self.assertTrue(slot.is_published)
        self.assertEqual(set(slot.questions.values_list("id", flat=True)), {q1.id, q2.id, q3.id})

    def test_force_new(self):
        create_topic_test(self.topic)
        self.assertEqual(next_test_number(self.topic), 2)
        q = self._q(9)
        dest = assign_question_to_test(q, self.topic, "new")
        self.assertEqual(dest.title, "Test 2")

    def test_rebalance_reduce_and_increase(self):
        from content.test_grouping import rebalance_topic_tests

        qs = [self._q(i) for i in range(1, 6)]
        t1 = create_topic_test(self.topic, force_number=1)
        t1.questions.set(qs)  # 5 soru, kapasite 2
        self.topic.questions_per_test = 2
        self.topic.save(update_fields=["questions_per_test"])
        summary = rebalance_topic_tests(self.topic)
        self.assertEqual(summary["questions"], 5)
        # Test 1–2 dolu, Test 3 kısmi; 5 yuva korunur
        tests = list(
            self.topic.tests.filter(is_published=True).order_by("created_at", "id")
        )
        self.assertGreaterEqual(len(tests), 3)
        self.assertEqual(tests[0].title, "Test 1")
        self.assertEqual(tests[0].questions.count(), 2)
        self.assertEqual(tests[1].questions.count(), 2)
        self.assertEqual(tests[2].questions.count(), 1)
        ids_before = {q.public_id for q in qs}

        self.topic.questions_per_test = 10
        self.topic.save(update_fields=["questions_per_test"])
        summary2 = rebalance_topic_tests(self.topic)
        self.assertEqual(summary2["questions"], 5)
        t1 = self.topic.tests.get(title="Test 1", is_published=True)
        self.assertEqual(t1.questions.count(), 5)
        ids_after = set(t1.questions.values_list("public_id", flat=True))
        self.assertEqual(ids_before, ids_after)
        # Boş yuvalar hâlâ var
        self.assertEqual(
            self.topic.tests.filter(is_published=True).count(),
            5,
        )

    def test_assign_moves_question_to_topic(self):
        other = Topic.objects.create(
            subject=self.subject,
            slug="t_other",
            name="Diğer Konu",
        )
        q = Question.objects.create(
            topic=other,
            public_id="q_foreign",
            stem="Yabancı",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )
        test = assign_question_to_test(q, self.topic, "auto")
        q.refresh_from_db()
        self.assertEqual(q.topic_id, self.topic.id)
        self.assertIn(q, test.questions.all())

    def test_detach_foreign_test_questions(self):
        from content.test_grouping import detach_foreign_test_questions

        other = Topic.objects.create(
            subject=self.subject,
            slug="t_other2",
            name="Diğer 2",
        )
        foreign = Question.objects.create(
            topic=other,
            public_id="q_foreign2",
            stem="Yabancı 2",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )
        test = create_topic_test(self.topic, force_number=1)
        test.questions.add(foreign)
        removed = detach_foreign_test_questions(self.topic)
        self.assertEqual(removed, 1)
        self.assertEqual(test.questions.count(), 0)


class OsymInterleaveTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(
            slug="t_osym", name="Tarih", sort_order=1
        )
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="t_osmanli",
            name="Osmanlı",
            questions_per_test=20,
        )

    def _q(self, i: int, *, osym: bool = False) -> Question:
        return Question.objects.create(
            topic=self.topic,
            public_id=f"q_osym_{i:02d}",
            stem=f"Soru {i}",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
            osym_sordu=osym,
        )

    def test_interleave_four_plus_one(self):
        from content.test_grouping import interleave_osym_questions

        plains = [self._q(i) for i in range(1, 17)]
        osyms = [self._q(100 + i, osym=True) for i in range(1, 5)]
        laid = interleave_osym_questions(plains + osyms)
        self.assertEqual(len(laid), 20)
        osym_indexes = [i for i, q in enumerate(laid) if q.osym_sordu]
        self.assertEqual(osym_indexes, [4, 9, 14, 19])

    def test_scarce_unlabeled_keeps_rest_in_order(self):
        from content.test_grouping import interleave_osym_questions

        laid = interleave_osym_questions(
            [
                self._q(1),
                self._q(2),
                self._q(3, osym=True),
                self._q(4, osym=True),
                self._q(5, osym=True),
            ]
        )
        self.assertEqual(
            [q.public_id for q in laid],
            ["q_osym_01", "q_osym_02", "q_osym_03", "q_osym_04", "q_osym_05"],
        )

    def test_rebalance_puts_four_osym_per_test(self):
        from content.test_grouping import rebalance_topic_tests

        plains = [self._q(i) for i in range(1, 33)]
        osyms = [self._q(200 + i, osym=True) for i in range(1, 9)]
        t1 = create_topic_test(self.topic, force_number=1)
        t1.questions.set(plains + osyms)
        summary = rebalance_topic_tests(self.topic)
        self.assertEqual(summary["questions"], 40)
        tests = list(
            self.topic.tests.filter(questions__isnull=False)
            .distinct()
            .order_by("created_at", "id")
        )
        filled = [t for t in self.topic.tests.order_by("created_at", "id") if t.questions.exists()]
        self.assertEqual(len(filled), 2)
        for test in filled:
            osym_count = test.questions.filter(osym_sordu=True).count()
            self.assertEqual(osym_count, 4)
            self.assertEqual(test.questions.count(), 20)
