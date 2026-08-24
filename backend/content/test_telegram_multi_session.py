from django.test import TestCase, override_settings

from content.models import Question, Subject, TelegramBotSession, Topic
from content.telegram_conversation import (
    start_solution_prompt,
    try_handle_conversation_callback,
)


class TelegramMultiSessionTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="turkce_ms", name="Turkce")
        self.topic = Topic.objects.create(
            subject=subject, slug="anlam_ms", name="Anlam"
        )

    def _q(self, public_id: str) -> Question:
        return Question.objects.create(
            topic=self.topic,
            public_id=public_id,
            stem="Soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )

    def test_two_photos_keep_separate_confirm_sessions(self):
        q1 = self._q("q_multi_1")
        q2 = self._q("q_multi_2")
        start_solution_prompt(42, 1001, q1, source_message_id=1)
        start_solution_prompt(42, 1001, q2, source_message_id=2)
        self.assertEqual(
            TelegramBotSession.objects.filter(telegram_user_id=42).count(), 2
        )

        reply = try_handle_conversation_callback("sol_no:q_multi_1", 42)
        self.assertIsNotNone(reply)
        self.assertFalse(TelegramBotSession.objects.filter(question=q1).exists())
        self.assertTrue(TelegramBotSession.objects.filter(question=q2).exists())

        reply2 = try_handle_conversation_callback("sol_yes:q_multi_2", 42)
        self.assertIsNotNone(reply2)
        self.assertIn("yapıştırın", reply2.text.lower())
        session = TelegramBotSession.objects.get(question=q2)
        self.assertEqual(session.step, TelegramBotSession.STEP_SOLUTION_TEXT)

    def test_reply_solution_queued_then_applied_on_ocr(self):
        from content.telegram_conversation import (
            consume_pending_solution_for_question,
            try_attach_solution_reply,
        )

        # OCR henüz yok — çözüm kuyruğa alınır.
        reply = try_attach_solution_reply(
            telegram_user_id=42,
            chat_id=1001,
            photo_message_id=555,
            text="Dogru cevap A cunku ...",
        )
        self.assertIsNotNone(reply)
        self.assertIn("not edildi", reply.text.lower())

        q = self._q("q_pending_sol")
        q.telegram_chat_id = 1001
        q.telegram_message_id = 555
        q.save(update_fields=["telegram_chat_id", "telegram_message_id"])

        applied = consume_pending_solution_for_question(
            q,
            chat_id=1001,
            photo_message_id=555,
            telegram_user_id=42,
        )
        self.assertIsNotNone(applied)
        q.refresh_from_db()
        self.assertIn("Dogru cevap A", q.solution)
        self.assertFalse(
            TelegramBotSession.objects.filter(question=q).exists()
        )


class TelegramDrainOcrWaitTests(TestCase):
    @override_settings(TELEGRAM_INLINE_PHOTOS=False)
    def test_wait_for_photo_queue_drains_submitted_work(self):
        import threading
        import time

        from content import telegram_bot as tb

        done = threading.Event()

        def slow_job() -> None:
            time.sleep(0.25)
            done.set()

        tb._submit_photo_work(slow_job)
        self.assertTrue(tb.wait_for_photo_queue(timeout_seconds=5))
        self.assertTrue(done.is_set())

    def test_wait_for_photo_queue_noop_when_idle(self):
        from content.telegram_bot import wait_for_photo_queue

        self.assertTrue(wait_for_photo_queue(timeout_seconds=1))
