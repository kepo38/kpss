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
        self.assertIsNone(reply2.delete_photo_message_id)
        session = TelegramBotSession.objects.get(question=q2)
        self.assertEqual(session.step, TelegramBotSession.STEP_SOLUTION_TEXT)

    def test_solution_text_not_stolen_by_later_photo_session(self):
        from content.telegram_conversation import try_handle_conversation

        q1 = self._q("q_keep_1")
        q2 = self._q("q_keep_2")
        start_solution_prompt(42, 1001, q1, source_message_id=1)
        try_handle_conversation_callback("sol_yes:q_keep_1", 42)
        start_solution_prompt(42, 1001, q2, source_message_id=2)
        reply = try_handle_conversation(42, "Dogru cevap A")
        self.assertIsNotNone(reply)
        q1.refresh_from_db()
        self.assertIn("Dogru cevap A", q1.solution)
        self.assertTrue(TelegramBotSession.objects.filter(question=q2).exists())

    def test_hayir_before_ocr_skips_second_prompt(self):
        from content.models import TelegramPendingSolution
        from content.telegram_conversation import (
            handle_photo_solution_decision,
            resolve_photo_intake_after_ocr,
        )

        handle_photo_solution_decision(
            telegram_user_id=42,
            chat_id=1001,
            photo_message_id=90,
            yes=False,
        )
        pending = TelegramPendingSolution.objects.get(
            chat_id=1001, photo_message_id=90
        )
        self.assertTrue(pending.skip_solution)

        q = self._q("q_skip_ocr")
        q.telegram_chat_id = 1001
        q.telegram_message_id = 90
        q.save(update_fields=["telegram_chat_id", "telegram_message_id"])
        outcome = resolve_photo_intake_after_ocr(
            q,
            chat_id=1001,
            photo_message_id=90,
            telegram_user_id=42,
        )
        self.assertFalse(outcome.include_solution_prompt)
        self.assertIsNone(outcome.reply)

    def test_photo_yes_callback_before_ocr(self):
        from content.models import TelegramPendingSolution
        from content.telegram_conversation import try_handle_conversation_callback

        reply = try_handle_conversation_callback(
            "sol_yes:m:91", 42, chat_id=1001
        )
        self.assertIsNotNone(reply)
        self.assertIn("yapıştırın", reply.text.lower())
        pending = TelegramPendingSolution.objects.get(
            chat_id=1001, photo_message_id=91
        )
        self.assertTrue(pending.awaiting_text)

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

    def test_caption_solution_queued_like_reply(self):
        from content.telegram_conversation import (
            consume_pending_solution_for_question,
            save_pending_solution_reply,
        )

        save_pending_solution_reply(
            telegram_user_id=42,
            chat_id=1001,
            photo_message_id=777,
            solution_text="Caption cozum A",
        )
        q = self._q("q_caption_sol")
        q.telegram_chat_id = 1001
        q.telegram_message_id = 777
        q.save(update_fields=["telegram_chat_id", "telegram_message_id"])
        applied = consume_pending_solution_for_question(
            q,
            chat_id=1001,
            photo_message_id=777,
            telegram_user_id=42,
        )
        self.assertIsNotNone(applied)
        q.refresh_from_db()
        self.assertIn("Caption cozum A", q.solution)

    def test_orphan_followup_text_binds_to_latest_photo(self):
        from content.models import TelegramPendingSolution
        from content.telegram_conversation import (
            consume_pending_solution_for_question,
            mark_photo_prompt_sent,
            try_attach_orphan_solution_text,
        )

        mark_photo_prompt_sent(
            telegram_user_id=42,
            chat_id=1001,
            photo_message_id=888,
        )
        pending = TelegramPendingSolution.objects.get(
            chat_id=1001, photo_message_id=888
        )
        self.assertEqual(pending.solution_text, "")

        reply = try_attach_orphan_solution_text(
            telegram_user_id=42,
            chat_id=1001,
            text=(
                "Metinde sanayileşmeyi temsil eden ifade doğrudan doğrular. "
                "Diğer seçenekler metinde yoktur ve çeldiricidir."
            ),
        )
        self.assertIsNotNone(reply)
        self.assertIn("not edildi", reply.text.lower())
        pending.refresh_from_db()
        self.assertIn("sanayileşmeyi", pending.solution_text)

        q = self._q("q_orphan_sol")
        q.telegram_chat_id = 1001
        q.telegram_message_id = 888
        q.save(update_fields=["telegram_chat_id", "telegram_message_id"])
        applied = consume_pending_solution_for_question(
            q,
            chat_id=1001,
            photo_message_id=888,
            telegram_user_id=42,
        )
        self.assertIsNotNone(applied)
        q.refresh_from_db()
        self.assertIn("sanayileşmeyi", q.solution)

    def test_yes_no_session_accepts_pasted_solution_without_reply(self):
        from content.telegram_conversation import try_handle_conversation

        q = self._q("q_yesno_paste")
        start_solution_prompt(42, 1001, q, source_message_id=12)
        reply = try_handle_conversation(
            42,
            "Metinde verilen cümle sanayileşmenin insan-eşya bağını "
            "değiştirdiğini doğrudan doğrular çünkü trajik biçimde anlatılır.",
        )
        self.assertIsNotNone(reply)
        q.refresh_from_db()
        self.assertIn("sanayileşmenin", q.solution)
        self.assertFalse(TelegramBotSession.objects.filter(question=q).exists())


class TelegramCaptionParseTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="mat_cap", name="Matematik")
        Topic.objects.create(
            subject=subject, slug="mat_problem", name="Problem", is_active=True
        )

    def test_empty_caption(self):
        from content.telegram_bot import _parse_photo_caption

        self.assertEqual(_parse_photo_caption(""), ("", "", False))
        self.assertEqual(_parse_photo_caption("  "), ("", "", False))

    def test_solution_marker_is_not_topic(self):
        from content.telegram_bot import _parse_photo_caption

        slug, sol, explicit = _parse_photo_caption(
            "çözüm: Doğru cevap A çünkü oran orantı."
        )
        self.assertEqual(slug, "")
        self.assertFalse(explicit)
        self.assertIn("Doğru cevap A", sol)

    def test_long_turkish_caption_is_solution_not_missing_topic(self):
        from content.telegram_bot import _parse_photo_caption

        slug, sol, explicit = _parse_photo_caption(
            "Doğru cevap C şıkkıdır çünkü metin bütünlüğü bozulmaz."
        )
        self.assertEqual(slug, "")
        self.assertFalse(explicit)
        self.assertTrue(sol.startswith("Doğru cevap C"))

    def test_first_line_known_slug_rest_is_solution(self):
        from content.telegram_bot import _parse_photo_caption

        slug, sol, explicit = _parse_photo_caption(
            "mat_problem\nCevap 12’dir."
        )
        self.assertEqual(slug, "mat_problem")
        self.assertTrue(explicit)
        self.assertEqual(sol, "Cevap 12’dir.")

    def test_unknown_underscore_token_stays_slug_error_path(self):
        from content.telegram_bot import _parse_photo_caption

        slug, sol, explicit = _parse_photo_caption("konu_yok_xyz")
        self.assertEqual(slug, "konu_yok_xyz")
        self.assertEqual(sol, "")
        self.assertTrue(explicit)


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
