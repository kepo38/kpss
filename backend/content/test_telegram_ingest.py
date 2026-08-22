import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

from django.contrib.auth.models import User
from django.db import IntegrityError
from django.test import TestCase, override_settings
from django.urls import reverse

from content.models import Question, Subject, Topic
from content.panel_context import pending_telegram_question_count
from content.telegram_panel import telegram_question_ocr_flags
from content.telegram_bot import (
    TelegramBotLockError,
    _allowed_user,
    _build_ingest_success_html,
    _format_elapsed,
    _resolve_topic,
    acquire_telegram_lock,
    drain_error_summary,
    ensure_polling_mode,
    handle_update,
    release_telegram_lock,
)


class TelegramBotHelperTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="matematik", name="Matematik")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="mat_problem",
            name="Problemler",
        )

    @override_settings(TELEGRAM_ALLOWED_USER_IDS=[12345])
    def test_allowed_user(self):
        self.assertTrue(_allowed_user(12345))
        self.assertFalse(_allowed_user(99999))

    @override_settings(TELEGRAM_DEFAULT_TOPIC_SLUG="mat_problem")
    def test_resolve_topic_from_caption(self):
        topic = _resolve_topic("mat_problem")
        self.assertEqual(topic.id, self.topic.id)

    @override_settings(TELEGRAM_DEFAULT_TOPIC_SLUG="mat_problem")
    def test_resolve_topic_default(self):
        topic = _resolve_topic("")
        self.assertEqual(topic.id, self.topic.id)

    @override_settings(TELEGRAM_DEFAULT_TOPIC_SLUG="mat_problem")
    def test_resolve_topic_invalid_slug_returns_none(self):
        self.assertIsNone(_resolve_topic("mat_problemm"))

    @override_settings(TELEGRAM_BOT_TOKEN="test-token")
    @patch("content.telegram_bot.clear_webhook_for_polling")
    @patch("content.telegram_bot.get_webhook_info")
    def test_ensure_polling_mode_clears_webhook(
        self, mock_info, mock_clear
    ):
        mock_info.return_value = {"url": "https://example.com/hook"}
        cleared = ensure_polling_mode()
        self.assertEqual(cleared, "https://example.com/hook")
        mock_clear.assert_called_once()

    @override_settings(TELEGRAM_BOT_TOKEN="test-token")
    @patch("content.telegram_bot.clear_webhook_for_polling")
    @patch("content.telegram_bot.get_webhook_info")
    def test_ensure_polling_mode_noop_without_webhook(
        self, mock_info, mock_clear
    ):
        mock_info.return_value = {"url": ""}
        self.assertIsNone(ensure_polling_mode())
        mock_clear.assert_not_called()


class TelegramIngestTests(TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls._settings_override = override_settings(TELEGRAM_INLINE_PHOTOS=True)
        cls._settings_override.enable()

    @classmethod
    def tearDownClass(cls):
        cls._settings_override.disable()
        super().tearDownClass()

    def setUp(self):
        self.subject = Subject.objects.create(slug="turkce", name="Türkçe")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="turkce_anlam",
            name="Sözcükte Anlam",
        )

    def _ocr_result(self):
        result = MagicMock()
        result.ok = True
        result.stem = "Test soru metni"
        result.options = {
            "A": "A şıkkı",
            "B": "B şıkkı",
            "C": "C şıkkı",
            "D": "D şıkkı",
            "E": "E şıkkı",
        }
        result.raw_text = "Test soru metni"
        result.figure_svg = ""
        result.correct_option = "B"
        result.solution = "Çözüm metni"
        result.engine = "gemini:test"
        result.error = ""
        return result

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    @patch("content.ocr_ingest._run_ocr")
    def test_handle_photo_creates_pending_question(
        self, mock_ocr, mock_download, mock_send, mock_delete
    ):
        mock_download.return_value = (b"fake-image", "image/jpeg")
        mock_ocr.return_value = (self._ocr_result(), "hash", "phash", True, False)

        handle_update(
            {
                "message": {
                    "message_id": 99,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc",
                            "file_unique_id": "uniq-99",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                    "caption": "turkce_anlam",
                }
            }
        )

        self.assertEqual(
            Question.objects.filter(
                submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                is_published=False,
            ).count(),
            1,
        )
        self.assertEqual(pending_telegram_question_count(), 1)
        mock_send.assert_called()
        full_reply = mock_send.call_args[0][1]
        self.assertIn("Soru alındı", full_reply)
        self.assertIn("⏱", full_reply)
        self.assertIn("Çözüm eklemek ister misiniz", full_reply)
        self.assertEqual(mock_send.call_args.kwargs.get("parse_mode"), "HTML")
        keyboard = mock_send.call_args.kwargs.get("reply_markup") or mock_send.call_args[1].get("reply_markup")
        self.assertIsNotNone(keyboard)
        self.assertEqual(keyboard["inline_keyboard"][0][0]["text"], "Evet")
        mock_delete.assert_not_called()

    def test_format_elapsed_seconds(self):
        self.assertEqual(_format_elapsed(0.2), "1 sn")
        self.assertEqual(_format_elapsed(28.4), "28 sn")
        self.assertEqual(_format_elapsed(90), "1 dk 30 sn")

    def test_ingest_html_shows_red_duplicate_warning(self):
        existing = Question.objects.create(
            topic=self.topic,
            public_id="q_dup_warn",
            stem="Benzer soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=True,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        created = Question.objects.create(
            topic=self.topic,
            public_id="q_new_warn",
            stem="Yeni soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        html = _build_ingest_success_html(
            topic=self.topic,
            question=created,
            pending=2,
            elapsed_seconds=31.2,
            forwarded=False,
            partial=False,
            duplicate=existing,
            include_solution_prompt=True,
        )
        self.assertIn("⏱ 31 sn", html)
        self.assertIn("🔴", html)
        self.assertIn("<b>Uyarı: benzer soru var", html)
        self.assertIn("<code>q_dup_warn</code>", html)

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot.edit_message_reply_markup")
    @patch("content.telegram_bot.answer_callback_query")
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    @patch("content.ocr_ingest._run_ocr")
    def test_solution_callback_yes_button(
        self, mock_ocr, mock_download, mock_send, mock_delete, mock_answer, mock_edit
    ):
        mock_download.return_value = (b"fake-image", "image/jpeg")
        mock_ocr.return_value = (self._ocr_result(), "hash", "phash", True, False)

        handle_update(
            {
                "message": {
                    "message_id": 104,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc5",
                            "file_unique_id": "uniq-104",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                }
            }
        )

        handle_update(
            {
                "callback_query": {
                    "id": "cb-1",
                    "from": {"id": 42},
                    "data": "sol_yes",
                    "message": {
                        "message_id": 500,
                        "chat": {"id": 1001},
                    },
                }
            }
        )

        mock_answer.assert_called_once()
        mock_delete.assert_called_once_with(1001, 104)
        mock_edit.assert_called_once_with(1001, 500, None)
        reply = mock_send.call_args_list[-1][0][1]
        self.assertIn("yapıştırın", reply.lower())

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    @patch("content.ocr_ingest._run_ocr")
    def test_solution_no_keeps_photo_in_chat(
        self, mock_ocr, mock_download, mock_send, mock_delete
    ):
        mock_download.return_value = (b"fake-image", "image/jpeg")
        mock_ocr.return_value = (self._ocr_result(), "hash", "phash", True, False)

        handle_update(
            {
                "message": {
                    "message_id": 102,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc3",
                            "file_unique_id": "uniq-102",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                }
            }
        )
        mock_delete.assert_not_called()

        handle_update(
            {
                "message": {
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "hayır",
                }
            }
        )
        mock_delete.assert_not_called()
        reply = mock_send.call_args[0][1]
        self.assertIn("sohbette kaldı", reply.lower())

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_conversation.refresh_question_embedding")
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    @patch("content.ocr_ingest._run_ocr")
    def test_solution_yes_deletes_photo_before_paste(
        self, mock_ocr, mock_download, mock_send, mock_delete, mock_embed
    ):
        mock_download.return_value = (b"fake-image", "image/jpeg")
        ocr = self._ocr_result()
        ocr.solution = ""
        mock_ocr.return_value = (ocr, "hash", "phash", True, False)

        handle_update(
            {
                "message": {
                    "message_id": 103,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc4",
                            "file_unique_id": "uniq-103",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                }
            }
        )
        mock_delete.assert_not_called()

        handle_update(
            {
                "message": {
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "evet",
                }
            }
        )
        mock_delete.assert_called_once_with(1001, 103)

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_conversation.refresh_question_embedding")
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    @patch("content.ocr_ingest._run_ocr")
    def test_solution_paste_flow(
        self, mock_ocr, mock_download, mock_send, mock_delete, mock_embed
    ):
        mock_download.return_value = (b"fake-image", "image/jpeg")
        ocr = self._ocr_result()
        ocr.solution = ""
        mock_ocr.return_value = (ocr, "hash", "phash", True, False)

        photo_update = {
            "message": {
                "message_id": 101,
                "chat": {"id": 1001},
                "from": {"id": 42},
                "photo": [
                    {
                        "file_id": "abc2",
                        "file_unique_id": "uniq-101",
                        "width": 100,
                        "height": 100,
                    }
                ],
            }
        }
        handle_update(photo_update)

        question = Question.objects.get(telegram_file_unique_id="uniq-101")
        self.assertEqual(question.solution, "")

        handle_update(
            {
                "message": {
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "evet",
                }
            }
        )
        mock_delete.assert_called_once_with(1001, 101)

        handle_update(
            {
                "message": {
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "Google'dan kopyalanan detaylı çözüm metni.",
                }
            }
        )

        question.refresh_from_db()
        self.assertEqual(
            question.solution,
            "Google'dan kopyalanan detaylı çözüm metni.",
        )
        mock_embed.assert_called_once()

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    def test_duplicate_forward_warns_and_deletes(
        self, mock_download, mock_send, mock_delete
    ):
        Question.objects.create(
            topic=self.topic,
            public_id="q_tg_existing",
            stem="Mevcut soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
            telegram_file_unique_id="uniq-dup",
        )

        outcome = handle_update(
            {
                "message": {
                    "message_id": 200,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "forward_date": 1700000000,
                    "photo": [
                        {
                            "file_id": "xyz",
                            "file_unique_id": "uniq-dup",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                }
            }
        )

        self.assertEqual(outcome, "skipped")
        self.assertEqual(Question.objects.count(), 1)
        mock_download.assert_not_called()
        warning = mock_send.call_args[0][1]
        self.assertIn("daha önce ilettiniz", warning.lower())
        mock_delete.assert_called_once_with(1001, 200)

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    def test_invalid_topic_slug_rejects_without_ingest(
        self, mock_download, mock_send
    ):
        outcome = handle_update(
            {
                "message": {
                    "message_id": 301,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc",
                            "file_unique_id": "uniq-bad-slug",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                    "caption": "mat_problemm",
                }
            }
        )

        self.assertEqual(outcome, "error")
        self.assertEqual(Question.objects.count(), 0)
        mock_download.assert_not_called()
        warning = mock_send.call_args[0][1]
        self.assertIn("konu bulunamadı", warning.lower())
        self.assertIn("mat_problemm", warning)
        self.assertIn("telegram.bat", warning.lower())

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
    )
    @patch("content.telegram_bot.peek_update_queue")
    @patch("content.telegram_bot.pending_telegram_question_count")
    @patch("content.telegram_bot.telegram_lock_active")
    @patch("content.telegram_bot.send_message")
    def test_durum_command_reports_status(
        self, mock_send, mock_lock_active, mock_pending, mock_peek
    ):
        mock_pending.return_value = 3
        mock_peek.return_value = (2, 1)
        mock_lock_active.return_value = False

        outcome = handle_update(
            {
                "message": {
                    "message_id": 50,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "/durum",
                }
            }
        )

        self.assertEqual(outcome, "command")
        body = mock_send.call_args[0][1]
        self.assertIn("onay bekleyen: 3", body.lower())
        self.assertIn("1 fotoğraf", body)
        self.assertIn("telegram.bat", body.lower())

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot.delete_message")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot.ingest_question_from_image")
    def test_integrity_error_race_treated_as_skipped(
        self, mock_ingest, mock_send, mock_delete
    ):
        Question.objects.create(
            topic=self.topic,
            public_id="q_race_existing",
            stem="Mevcut",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
            telegram_file_unique_id="uniq-race",
        )
        mock_ingest.side_effect = IntegrityError("unique")

        outcome = handle_update(
            {
                "message": {
                    "message_id": 401,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc",
                            "file_unique_id": "uniq-race",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                }
            }
        )

        self.assertEqual(outcome, "skipped")
        self.assertEqual(Question.objects.count(), 1)
        mock_delete.assert_called_once_with(1001, 401)

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
        TELEGRAM_DEFAULT_TOPIC_SLUG="turkce_anlam",
    )
    @patch("content.telegram_bot._find_existing_after_conflict")
    @patch("content.telegram_bot.send_message")
    @patch("content.telegram_bot._download_file")
    @patch("content.telegram_bot.ingest_question_from_image")
    def test_integrity_error_without_row_uses_retry_lookup(
        self, mock_ingest, mock_download, mock_send, mock_after_conflict
    ):
        mock_download.return_value = (b"fake-image", "image/jpeg")
        mock_ingest.side_effect = IntegrityError("unique")
        mock_after_conflict.return_value = (None, None)

        outcome = handle_update(
            {
                "message": {
                    "message_id": 402,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "photo": [
                        {
                            "file_id": "abc",
                            "file_unique_id": "uniq-race-miss",
                            "width": 100,
                            "height": 100,
                        }
                    ],
                }
            }
        )

        self.assertEqual(outcome, "error")
        mock_after_conflict.assert_called_once()
        body = mock_send.call_args[0][1]
        self.assertIn("çakışması", body.lower())

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
    )
    @patch("content.telegram_bot.send_message")
    def test_sohbeti_sil_clears_without_stopping_bot(self, mock_send):
        from content.models import TelegramBotSession

        question = Question.objects.create(
            topic=self.topic,
            public_id="q_clear_chat",
            stem="Soru",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        TelegramBotSession.objects.create(
            telegram_user_id=42,
            chat_id=1001,
            step=TelegramBotSession.STEP_SOLUTION_YES_NO,
            question=question,
            source_message_id=777,
        )
        mock_send.return_value = 999

        outcome = handle_update(
            {
                "message": {
                    "message_id": 888,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "sohbeti sil",
                }
            }
        )

        self.assertEqual(outcome, "command")
        self.assertFalse(
            TelegramBotSession.objects.filter(telegram_user_id=42).exists()
        )
        reply = mock_send.call_args[0][1]
        self.assertIn("dinlemeye devam", reply.lower())
        self.assertNotIn("kapan", reply.lower())

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
    )
    @patch("content.telegram_bot._try_delete_message")
    @patch("content.telegram_bot.send_message")
    def test_sohbeti_sil_deletes_tracked_user_and_bot_messages(
        self, mock_send, mock_delete
    ):
        from content import telegram_bot

        telegram_bot._chat_message_ids.clear()
        telegram_bot._chat_messages_loaded = True
        telegram_bot._chat_message_ids[1001] = [101, 202, 303]
        mock_delete.return_value = True
        mock_send.return_value = 999

        outcome = handle_update(
            {
                "message": {
                    "message_id": 888,
                    "chat": {"id": 1001},
                    "from": {"id": 42},
                    "text": "/sohbeti_sil",
                }
            }
        )

        self.assertEqual(outcome, "command")
        deleted_ids = {
            call.args[1] for call in mock_delete.call_args_list if len(call.args) > 1
        }
        self.assertIn(888, deleted_ids)
        self.assertIn(101, deleted_ids)
        self.assertIn(202, deleted_ids)
        self.assertIn(303, deleted_ids)
        reply = mock_send.call_args[0][1]
        self.assertIn("Silinen mesaj:", reply)

    @override_settings(
        TELEGRAM_BOT_TOKEN="test-token",
        TELEGRAM_ALLOWED_USER_IDS=[42],
    )
    @patch("content.telegram_bot.send_message")
    def test_rejects_unauthorized_user(self, mock_send):
        handle_update(
            {
                "message": {
                    "message_id": 1,
                    "chat": {"id": 1001},
                    "from": {"id": 999},
                    "text": "/start",
                }
            }
        )
        mock_send.assert_called()
        self.assertIn("yetkili", mock_send.call_args[0][1].lower())


class PendingQuestionPanelTests(TestCase):
    def setUp(self):
        self.staff = User.objects.create_user(
            username="pending-staff",
            password="secret",
            is_staff=True,
        )
        self.subject = Subject.objects.create(slug="tarih", name="Tarih")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="tarih_inkilaplar",
            name="İnkılaplar",
        )
        self.question = Question.objects.create(
            topic=self.topic,
            public_id="q_tg_pending",
            stem="Telegram sorusu",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )

    def test_panel_shows_pending_count(self):
        self.client.force_login(self.staff)
        response = self.client.get(reverse("panel_pending_questions"))
        self.assertContains(response, "q_tg_pending")
        self.assertContains(response, 'pending-count">1</span>')

    def test_risky_questions_sorted_first(self):
        risky = Question.objects.create(
            topic=self.topic,
            public_id="q_tg_risky",
            stem="Aşağıdaki görsele göre cevaplayınız.",
            option_a="—",
            option_b="—",
            option_c="—",
            option_d="—",
            option_e="—",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        self.client.force_login(self.staff)
        response = self.client.get(reverse("panel_pending_questions"))
        self.assertEqual(response.status_code, 200)
        content = response.content.decode()
        self.assertLess(
            content.index("q_tg_risky"),
            content.index("q_tg_pending"),
        )
        self.assertIn("Kısmi OCR", content)
        self.assertContains(response, "Riskli")

    def test_filter_risky_only(self):
        Question.objects.create(
            topic=self.topic,
            public_id="q_tg_risky_only",
            stem="Aşağıdaki görsele göre cevaplayınız.",
            option_a="—",
            option_b="—",
            option_c="—",
            option_d="D",
            option_e="E",
            is_published=False,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        self.client.force_login(self.staff)
        response = self.client.get(reverse("panel_pending_questions") + "?filter=risky")
        self.assertContains(response, "q_tg_risky_only")
        self.assertNotContains(response, "q_tg_pending")

    def test_edit_save_publishes_and_leaves_pending_list(self):
        self.client.force_login(self.staff)
        url = reverse(
            "panel_question_edit",
            kwargs={"topic_id": self.topic.id, "question_id": self.question.id},
        )
        response = self.client.post(
            url,
            data={
                "stem": self.question.stem,
                "option_a": "A",
                "option_b": "B",
                "option_c": "C",
                "option_d": "D",
                "option_e": "E",
                "correct_option": "A",
                "solution": "",
                "is_published": "on",
                "test_assignment": "auto",
            },
        )
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, reverse("panel_pending_questions"))
        self.question.refresh_from_db()
        self.assertTrue(self.question.is_published)
        self.assertEqual(pending_telegram_question_count(), 0)

    def test_pending_list_has_inspect_not_approve(self):
        self.client.force_login(self.staff)
        response = self.client.get(reverse("panel_pending_questions"))
        self.assertContains(response, "İncele")
        self.assertNotContains(response, ">Onayla</button>")

    def test_reject_deletes_question(self):
        self.client.force_login(self.staff)
        response = self.client.post(
            reverse(
                "panel_pending_question_reject",
                kwargs={"question_id": self.question.id},
            )
        )
        self.assertEqual(response.status_code, 302)
        self.assertFalse(Question.objects.filter(pk=self.question.id).exists())


class TelegramLockTests(TestCase):
    def test_lock_blocks_second_acquire(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock_path = Path(tmp) / "telegram_bot.lock"
            with self.settings(TELEGRAM_LOCK_FILE=str(lock_path)):
                acquire_telegram_lock()
                try:
                    with self.assertRaises(TelegramBotLockError):
                        acquire_telegram_lock()
                finally:
                    release_telegram_lock()
            self.assertFalse(lock_path.exists())

    def test_stale_lock_is_replaced(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock_path = Path(tmp) / "telegram_bot.lock"
            lock_path.write_text("999999999", encoding="utf-8")
            with self.settings(TELEGRAM_LOCK_FILE=str(lock_path)):
                acquire_telegram_lock()
                try:
                    self.assertTrue(lock_path.exists())
                    self.assertNotEqual(lock_path.read_text(encoding="utf-8"), "999999999")
                finally:
                    release_telegram_lock()


class TelegramOcrFlagsTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="mat", name="Matematik")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="mat_test",
            name="Test",
        )

    def test_placeholder_stem_marked_risky(self):
        question = Question.objects.create(
            topic=self.topic,
            public_id="q_flags_1",
            stem="Aşağıdaki görsele göre cevaplayınız.",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        flags = telegram_question_ocr_flags(question)
        self.assertTrue(flags.partial)
        self.assertTrue(flags.is_risky)


class TelegramFileUniqueConstraintTests(TestCase):
    def setUp(self):
        self.subject = Subject.objects.create(slug="cografya", name="Coğrafya")
        self.topic = Topic.objects.create(
            subject=self.subject,
            slug="cog_harita",
            name="Harita",
        )

    def test_duplicate_telegram_file_unique_id_rejected(self):
        Question.objects.create(
            topic=self.topic,
            public_id="q_uid_1",
            stem="Soru 1",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
            telegram_file_unique_id="same-file-uid",
        )
        with self.assertRaises(IntegrityError):
            Question.objects.create(
                topic=self.topic,
                public_id="q_uid_2",
                stem="Soru 2",
                option_a="A",
                option_b="B",
                option_c="C",
                option_d="D",
                option_e="E",
                submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                telegram_file_unique_id="same-file-uid",
            )

    def test_empty_telegram_file_unique_id_allows_multiple(self):
        Question.objects.create(
            topic=self.topic,
            public_id="q_empty_1",
            stem="Soru 1",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
        )
        Question.objects.create(
            topic=self.topic,
            public_id="q_empty_2",
            stem="Soru 2",
            option_a="A",
            option_b="B",
            option_c="C",
            option_d="D",
            option_e="E",
        )
        self.assertEqual(Question.objects.count(), 2)

    def test_drain_error_summary_format(self):
        self.assertIn(
            "fotoğraflar bot sohbetinde",
            drain_error_summary(2).lower(),
        )
