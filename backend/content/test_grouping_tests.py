from django.test import TestCase

from content.models import Question, Subject, Topic
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
        self.assertEqual(summary["tests"], 3)  # 2+2+1
        self.assertEqual(summary["questions"], 5)
        tests = list(self.topic.tests.order_by("created_at", "id"))
        self.assertEqual([t.questions.count() for t in tests], [2, 2, 1])
        ids_before = {q.public_id for q in qs}

        self.topic.questions_per_test = 10
        self.topic.save(update_fields=["questions_per_test"])
        summary2 = rebalance_topic_tests(self.topic)
        self.assertEqual(summary2["tests"], 1)
        self.assertEqual(summary2["questions"], 5)
        t = self.topic.tests.get()
        self.assertEqual(t.title, "Test 1")
        self.assertEqual(t.questions.count(), 5)
        ids_after = set(t.questions.values_list("public_id", flat=True))
        self.assertEqual(ids_before, ids_after)

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
