from django.test import TestCase

from content.models import Question, Subject, Topic, TopicTest
from content.serializers import TopicTestSerializer


class TopicTestSerializerPublishedOnlyTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="ser_subj", name="Ser", sort_order=1)
        self.topic = Topic.objects.create(
            subject=subject, slug="ser_topic", name="Ser Konu"
        )
        self.test = TopicTest.objects.create(
            topic=self.topic,
            public_id="test_ser_1",
            title="Test 1",
            is_published=True,
        )
        self.pub = Question.objects.create(
            topic=self.topic,
            public_id="q_ser_pub",
            stem="Yayında",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )
        self.draft = Question.objects.create(
            topic=self.topic,
            public_id="q_ser_draft",
            stem="Taslak",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=False,
        )
        self.test.questions.add(self.pub, self.draft)

    def test_excludes_foreign_topic_questions(self):
        other = Topic.objects.create(
            subject=self.topic.subject,
            slug="ser_other",
            name="Başka Konu",
        )
        foreign = Question.objects.create(
            topic=other,
            public_id="q_ser_foreign",
            stem="Başka konu sorusu",
            option_a="a",
            option_b="b",
            option_c="c",
            option_d="d",
            option_e="e",
            correct_option="A",
            is_published=True,
        )
        self.test.questions.add(foreign)
        data = TopicTestSerializer(self.test).data
        self.assertEqual(data["questionCount"], 1)
        self.assertEqual(data["questionIds"], ["q_ser_pub"])

    def test_counts_only_published(self):
        data = TopicTestSerializer(self.test).data
        self.assertEqual(data["questionCount"], 1)
        self.assertEqual(data["questionIds"], ["q_ser_pub"])
