from django.contrib.auth import get_user_model
from django.test import TestCase

from content.models import Question, QuestionScenario, Subject, Topic, TopicTest
from content.serializers import QuestionSerializer, TopicTestSerializer
from content.test_grouping import (
    assign_question_to_test,
    order_questions_keeping_scenarios,
    rebalance_topic_tests,
)


class QuestionScenarioTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="tr_sc", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="sozel_mantik",
            name="Sözel Mantık",
            questions_per_test=3,
        )
        self.scenario = QuestionScenario.objects.create(
            topic=self.topic,
            title="Otobüs yolculuğu",
            stem="Ali, Ayşe ve Can aynı otobüste oturmaktadır.",
            sort_order=1,
            is_published=True,
        )

    def _q(self, i: int, **kwargs) -> Question:
        defaults = dict(
            topic=self.topic,
            public_id=f"q_sc_{i}",
            stem=f"Soru {i}",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )
        defaults.update(kwargs)
        return Question.objects.create(**defaults)

    def test_order_keeps_group_contiguous(self):
        lone = self._q(1)
        q3 = self._q(3, scenario=self.scenario, scenario_order=2)
        q2 = self._q(2, scenario=self.scenario, scenario_order=1)
        q4 = self._q(4, scenario=self.scenario, scenario_order=3)
        ordered = order_questions_keeping_scenarios([lone, q3, q2, q4])
        self.assertEqual(
            [q.public_id for q in ordered],
            ["q_sc_2", "q_sc_3", "q_sc_4", "q_sc_1"],
        )

    def test_serializer_exposes_published_scenario(self):
        q = self._q(1, scenario=self.scenario, scenario_order=2)
        data = QuestionSerializer(q).data
        self.assertEqual(data["scenarioId"], str(self.scenario.id))
        self.assertEqual(data["scenarioTitle"], "Otobüs yolculuğu")
        self.assertIn("Ali", data["scenarioStem"])
        self.assertEqual(data["scenarioOrder"], 2)

    def test_unpublished_scenario_hidden_from_api(self):
        self.scenario.is_published = False
        self.scenario.save(update_fields=["is_published"])
        q = self._q(1, scenario=self.scenario, scenario_order=1)
        data = QuestionSerializer(q).data
        self.assertIsNone(data["scenarioId"])
        self.assertIsNone(data["scenarioStem"])

    def test_test_question_ids_follow_group_order(self):
        lone = self._q(9)
        q2 = self._q(2, scenario=self.scenario, scenario_order=2)
        q1 = self._q(1, scenario=self.scenario, scenario_order=1)
        test = TopicTest.objects.create(
            topic=self.topic,
            public_id="test_sc_1",
            title="Test 1",
            is_published=True,
        )
        test.questions.add(lone, q2, q1)
        data = TopicTestSerializer(test).data
        self.assertEqual(data["questionIds"], ["q_sc_1", "q_sc_2", "q_sc_9"])

    def test_rebalance_does_not_split_scenario(self):
        group = [
            self._q(i, scenario=self.scenario, scenario_order=i)
            for i in range(1, 4)
        ]
        extra = self._q(8)
        test = TopicTest.objects.create(
            topic=self.topic,
            public_id="test_sc_rb",
            title="Test 1",
            is_published=True,
        )
        test.questions.set(group + [extra])
        self.topic.questions_per_test = 2
        self.topic.save(update_fields=["questions_per_test"])
        summary = rebalance_topic_tests(self.topic)
        self.assertEqual(summary["tests"], 2)
        tests = list(self.topic.tests.order_by("created_at", "id"))
        grouped_test = next(
            t
            for t in tests
            if t.questions.filter(scenario=self.scenario).count() == 3
        )
        self.assertEqual(grouped_test.questions.count(), 3)
        self.assertTrue(
            extra in tests[0].questions.all() or extra in tests[1].questions.all()
        )

    def test_assign_auto_joins_sibling_test(self):
        first = self._q(1, scenario=self.scenario, scenario_order=1)
        t1 = assign_question_to_test(first, self.topic, "auto")
        self.topic.questions_per_test = 1
        self.topic.save(update_fields=["questions_per_test"])
        second = self._q(2, scenario=self.scenario, scenario_order=2)
        dest = assign_question_to_test(second, self.topic, "auto")
        self.assertEqual(dest.id, t1.id)
        self.assertEqual(t1.questions.count(), 2)

    def test_panel_creates_and_assigns_scenario(self):
        User = get_user_model()
        staff = User.objects.create_user(
            username="sc_staff", password="x", is_staff=True
        )
        self.client.force_login(staff)
        res = self.client.post(
            f"/panel/konu/{self.topic.id}/grup/yeni/",
            {
                "title": "Yeni olay",
                "stem": "Ortak metin burada.",
                "sort_order": "2",
                "is_published": "on",
            },
        )
        self.assertEqual(res.status_code, 302)
        created = QuestionScenario.objects.get(title="Yeni olay")
        qres = self.client.post(
            f"/panel/konu/{self.topic.id}/soru/yeni/",
            {
                "subject_id": self.subject.id,
                "topic_id": self.topic.id,
                "stem": "Bu olaydan hangisi çıkarılır?",
                "option_a": "A",
                "option_b": "B",
                "option_c": "C",
                "option_d": "D",
                "option_e": "E",
                "correct_option": "A",
                "test_assignment": "auto",
                "scenario_id": str(created.id),
                "scenario_order": "3",
                "is_published": "on",
            },
        )
        self.assertEqual(qres.status_code, 302)
        question = Question.objects.get(topic=self.topic, stem__startswith="Bu olay")
        self.assertEqual(question.scenario_id, created.id)
        self.assertEqual(question.scenario_order, 3)
