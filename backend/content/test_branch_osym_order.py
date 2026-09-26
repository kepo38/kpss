from django.test import TestCase

from content.exam_pack_generator import generate_pack_exams
from content.models import (
    ExamDistributionTemplate,
    ExamPack,
    ExamPackExamQuestion,
    ExamType,
    Question,
    Subject,
    Topic,
)
from content.osym_exam_order import OSYM_TARIH


def _quality_question(*, topic: Topic, public_id: str) -> Question:
    return Question.objects.create(
        public_id=public_id,
        topic=topic,
        stem=f"Soru {public_id}",
        option_a="A",
        option_b="B",
        option_c="C",
        option_d="D",
        option_e="E",
        correct_option="A",
        is_published=True,
        difficulty=Question.DIFFICULTY_MEDIUM,
        attempt_count=Question.DIFFICULTY_MIN_ATTEMPTS,
    )


class BranchOsymOrderTests(TestCase):
    def setUp(self):
        self.exam_type = ExamType.objects.create(
            slug="kpss_osym_branch",
            name="KPSS ÖSYM",
            exam_date="2026-07-12",
        )
        self.subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topics = {}
        for slot in OSYM_TARIH:
            for slug in slot.topic_slugs:
                if slug in self.topics:
                    continue
                self.topics[slug] = Topic.objects.create(
                    subject=self.subject,
                    slug=slug,
                    name=slug,
                    sort_order=len(self.topics),
                )
        for slug, topic in self.topics.items():
            for i in range(5):
                _quality_question(topic=topic, public_id=f"q_osym_{slug}_{i}")

        ExamDistributionTemplate.objects.create(
            exam_type=self.exam_type,
            subject=self.subject,
            question_count=27,
        )
        self.pack = ExamPack.objects.create(
            public_id="ep_osym_tarih",
            exam_type=self.exam_type,
            pack_kind=ExamPack.PACK_KIND_BRANCH,
            subject=self.subject,
            title="Tarih Branş",
            exam_count=1,
            is_published=True,
        )

    def test_branch_exam_follows_osym_topic_order(self):
        generate_pack_exams(self.pack, replace=True, seed=7)
        rows = list(
            ExamPackExamQuestion.objects.filter(exam__pack=self.pack)
            .select_related("question__topic")
            .order_by("sort_order")
        )
        self.assertEqual(len(rows), 27)
        topic_slugs = [row.question.topic.slug for row in rows]
        # İlk soru İslamiyet öncesi, son blok çağdaş tarih.
        self.assertEqual(topic_slugs[0], "tarih_islamiyet_oncesi")
        self.assertIn("tarih_cagdas_turk_dunya", topic_slugs[-3:])
