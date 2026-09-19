from django.test import TestCase, override_settings
from django.urls import reverse

from content.embeddings import cosine_similarity, local_embedding, refresh_question_embedding
from content.models import Question, Subject, Topic


class EmbeddingMathTests(TestCase):
    def test_identical_vectors_are_one(self):
        vector = local_embedding("paragraf ana fikir")
        self.assertAlmostEqual(cosine_similarity(vector, vector), 1.0, places=6)

    def test_overlapping_turkish_stems_rank_higher(self):
        source = local_embedding("Paragraf sorusunda ana fikir nedir?")
        close = local_embedding("Bu paragrafta ana fikir aşağıdakilerden hangisidir?")
        far = local_embedding("Türev ve integral hesaplaması yapınız.")
        self.assertGreater(
            cosine_similarity(source, close),
            cosine_similarity(source, far),
        )

    @override_settings(OPENAI_API_KEY="")
    def test_refresh_skips_unchanged_hash(self):
        subject = Subject.objects.create(slug="tr_hash", name="Türkçe")
        topic = Topic.objects.create(subject=subject, slug="tr_hash_p", name="Paragraf")
        question = Question.objects.create(
            topic=topic,
            public_id="q_emb_hash",
            stem="Ana fikir nedir?",
            option_a="I",
            option_b="II",
            option_c="III",
            option_d="IV",
            option_e="V",
            correct_option="A",
            is_published=True,
        )
        self.assertTrue(refresh_question_embedding(question, force=True))
        self.assertFalse(refresh_question_embedding(question))


@override_settings(OPENAI_API_KEY="")
class SimilarQuestionsApiTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="tr_emb", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=self.subject, slug="tr_emb_p", name="Paragraf"
        )
        self.source = self._make("q_emb_src", "Paragrafta ana fikir hangisidir?")
        self.near = self._make("q_emb_near", "Bu paragrafın ana fikri nedir?")
        self.far = self._make(
            "q_emb_far", "Hangisinde yazım yanlışı vardır?"
        )
        math_subject = Subject.objects.create(slug="mat_emb", name="Matematik")
        math_topic = Topic.objects.create(
            subject=math_subject, slug="mat_emb_t", name="Türev"
        )
        self.math = Question.objects.create(
            topic=math_topic,
            public_id="q_emb_math",
            stem="f(x)=x^2 fonksiyonunun türevi nedir?",
            option_a="2x",
            option_b="x",
            option_c="x^2",
            option_d="2",
            option_e="0",
            correct_option="A",
            is_published=True,
        )
        self._set_vector(self.source, [1.0, 0.0, 0.0])
        self._set_vector(self.near, [0.97, 0.24, 0.0])
        self._set_vector(self.far, [0.2, 0.98, 0.0])
        self._set_vector(self.math, [0.0, 0.0, 1.0])

    def _make(self, public_id: str, stem: str) -> Question:
        return Question.objects.create(
            topic=self.topic,
            public_id=public_id,
            stem=stem,
            option_a="I",
            option_b="II",
            option_c="III",
            option_d="IV",
            option_e="V",
            correct_option="A",
            is_published=True,
        )

    def _set_vector(self, question: Question, vector: list[float]) -> None:
        question.embedding = vector
        question.embedding_model = "test"
        question.embedding_hash = "manual"
        question.save(
            update_fields=["embedding", "embedding_model", "embedding_hash"]
        )

    def test_similar_endpoint_ranks_near_question_first(self):
        url = reverse("question-similar", kwargs={"public_id": self.source.public_id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["sourceId"], self.source.public_id)
        ids = [item["id"] for item in body["questions"]]
        self.assertEqual(ids[0], self.near.public_id)
        self.assertNotIn(self.source.public_id, ids)
        self.assertIn("similarity", body["questions"][0])

    def test_near_duplicate_copy_is_excluded(self):
        dup = self._make(
            "q_emb_dup",
            "Paragrafta ana fikir hangisidir?",
        )
        self._set_vector(dup, [0.99, 0.1, 0.0])
        from content.embeddings import similar_questions

        scored = similar_questions(self.source, limit=5, threshold=0.5)
        ids = [candidate.public_id for _, candidate in scored]
        self.assertNotIn(dup.public_id, ids)
        self.assertNotIn(self.source.public_id, ids)

    def test_unpublished_source_is_not_found(self):
        self.source.is_published = False
        self.source.save(update_fields=["is_published"])
        url = reverse("question-similar", kwargs={"public_id": self.source.public_id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 404)
