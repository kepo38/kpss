from datetime import timedelta

from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from content.daily_mini_exam import (
    exam_date_for,
    guest_login_required,
    lcg_shuffle,
    pick_question_ids,
    split_frosted_email,
)
from content.models import AppUser, Question, Subject, Topic


class DailyMiniExamLogicTests(TestCase):
    def test_frosted_email_masks_after_three_chars(self):
        self.assertEqual(
            split_frosted_email("ahmet@gmail.com"),
            ("ahm", "•••@gmail.com"),
        )
        self.assertEqual(
            split_frosted_email("ahmet.yilmaz@example.com"),
            ("ahm", "•••@example.com"),
        )
        self.assertEqual(split_frosted_email("ali@x.com"), ("ali", "@x.com"))
        self.assertEqual(split_frosted_email("ab"), ("ab", ""))

    def test_lcg_shuffle_is_deterministic(self):
        items = [f"q{i}" for i in range(10)]
        self.assertEqual(lcg_shuffle(items, 42), lcg_shuffle(items, 42))
        self.assertNotEqual(lcg_shuffle(items, 42), lcg_shuffle(items, 43))


class DailyMiniExamApiTests(TestCase):
    def setUp(self):
        pools = {
            "tarih": ("tarih", "Tarih", "tarih_osmanli_19", "Osmanlı 19. yy"),
            "cografya": ("cografya", "Coğrafya", "cografya_iklim", "İklim"),
            "vatandaslik": (
                "vatandaslik",
                "Vatandaşlık",
                "vatandaslik_anayasa",
                "Anayasa",
            ),
            "turkce_anlam": ("turkce", "Türkçe", "turkce_anlam", "Sözcükte Anlam"),
            "turkce_dilbilgisi": (
                "turkce",
                "Türkçe",
                "turkce_dilbilgisi",
                "Dil Bilgisi",
            ),
        }
        subjects: dict[str, Subject] = {}
        topics: dict[str, Topic] = {}
        for key, (subj_slug, subj_name, topic_slug, topic_name) in pools.items():
            if subj_slug not in subjects:
                subjects[subj_slug] = Subject.objects.create(
                    slug=subj_slug, name=subj_name
                )
            topics[key] = Topic.objects.create(
                subject=subjects[subj_slug],
                slug=topic_slug,
                name=topic_name,
            )

        n = 0
        for topic in topics.values():
            for _ in range(6):
                n += 1
                Question.objects.create(
                    topic=topic,
                    public_id=f"q_mini_{n}",
                    stem=f"Soru {n}?",
                    option_a="A",
                    option_b="B",
                    option_c="C",
                    option_d="D",
                    option_e="E",
                    correct_option="A",
                    is_published=True,
                )

        self.user = AppUser.objects.create(
            google_sub="mini-sub-1",
            email="ahmet.yilmaz@example.com",
            display_name="Ahmet",
            api_token="mini-token-1",
        )
        self.other = AppUser.objects.create(
            google_sub="mini-sub-2",
            email="zeynep@example.com",
            display_name="Zeynep",
            api_token="mini-token-2",
        )

    def auth(self, user=None):
        selected = user or self.user
        return {"HTTP_AUTHORIZATION": f"Bearer {selected.api_token}"}

    def url(self):
        return reverse("daily-mini-exam")

    def _open_now(self):
        now = timezone.localtime()
        return now.replace(hour=10, minute=0, second=0, microsecond=0)

    def test_pick_counts_per_pool(self):
        ids = pick_question_ids(timezone.localdate(), "lisans")
        self.assertEqual(len(ids), 20)
        self.assertEqual(len(set(ids)), 20)

    def test_get_returns_exam_and_empty_board(self):
        with patch(
            "content.daily_mini_exam.istanbul_now", return_value=self._open_now()
        ):
            response = self.client.get(self.url(), {"kpss_type": "lisans"})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["isOpen"])
        self.assertEqual(len(body["questionIds"]), 20)
        self.assertEqual(body["participantCount"], 0)

    def test_blank_submit_does_not_lock_ranking(self):
        from content.models import DailyMiniExamAttempt

        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth()
            ).json()
            empty = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": {},
                    "duration_seconds": 5,
                },
                content_type="application/json",
                **self.auth(),
            )
            self.assertEqual(empty.status_code, 400)
            self.assertIsNone(
                self.client.get(
                    self.url(), {"kpss_type": "lisans"}, **self.auth()
                ).json()["myAttempt"]
            )
            DailyMiniExamAttempt.objects.create(
                user=self.user,
                exam_date=exam_date_for(open_now),
                kpss_type="lisans",
                correct=0,
                wrong=0,
                blank=20,
                total=20,
                duration_seconds=5,
                wrong_question_ids=[],
                answers={},
            )
            locked = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth()
            ).json()
            self.assertIsNone(locked["myAttempt"])
            qids = exam["questionIds"]
            real = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": {qids[0]: "A"},
                    "duration_seconds": 40,
                },
                content_type="application/json",
                **self.auth(),
            )
            self.assertEqual(real.status_code, 201)
            self.assertIsNotNone(real.json()["myAttempt"])


    def test_submit_grades_and_ranks(self):
        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth()
            ).json()
            qids = exam["questionIds"]
            answers = {qid: "A" for qid in qids[:16]}
            for qid in qids[16:]:
                answers[qid] = "B"
            first = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": answers,
                    "duration_seconds": 400,
                },
                content_type="application/json",
                **self.auth(),
            )
            self.assertEqual(first.status_code, 201)
            mine = first.json()["myAttempt"]
            self.assertEqual(mine["correct"], 16)
            self.assertEqual(mine["wrong"], 4)
            self.assertEqual(mine["rank"], 1)

            weaker = {qid: "B" for qid in qids}
            second = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": weaker,
                    "duration_seconds": 200,
                },
                content_type="application/json",
                **self.auth(self.other),
            )
            self.assertEqual(second.status_code, 201)
            board = second.json()["leaderboard"]
            self.assertEqual(board[0]["userId"], str(self.user.pk))
            self.assertEqual(board[0]["emailPrefix"], "ahm")
            self.assertEqual(board[0]["displayName"], "Ahmet")
            self.assertEqual(board[1]["rank"], 2)
            self.assertEqual(second.json()["participantCount"], 2)

    def test_equal_score_ranks_by_duration(self):
        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth()
            ).json()
            qids = exam["questionIds"]
            answers = {qid: "A" for qid in qids[:18]}
            for qid in qids[18:]:
                answers[qid] = "B"
            self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": answers,
                    "duration_seconds": 900,
                },
                content_type="application/json",
                **self.auth(),
            )
            self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": answers,
                    "duration_seconds": 600,
                },
                content_type="application/json",
                **self.auth(self.other),
            )
            board = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth(self.other)
            ).json()["leaderboard"]
        self.assertEqual(board[0]["userId"], str(self.other.pk))
        self.assertEqual(board[1]["userId"], str(self.user.pk))

    def test_closed_window_rejects_submit(self):
        now = timezone.localtime().replace(
            hour=2, minute=0, second=0, microsecond=0
        )
        with patch("content.daily_mini_exam.istanbul_now", return_value=now):
            response = self.client.post(
                self.url(),
                data={"kpss_type": "lisans", "answers": {}},
                content_type="application/json",
                **self.auth(),
            )
        self.assertEqual(response.status_code, 403)

    def test_pre_open_shows_yesterday_leaderboard(self):
        yesterday_open = timezone.localtime().replace(
            hour=10, minute=0, second=0, microsecond=0
        ) - timedelta(days=1)
        with patch("content.daily_mini_exam.istanbul_now", return_value=yesterday_open):
            exam = self.client.get(self.url(), {"kpss_type": "lisans"}).json()
            answers = {qid: "A" for qid in exam["questionIds"]}
            self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": answers,
                    "duration_seconds": 400,
                },
                content_type="application/json",
                **self.auth(),
            )

        pre_open = timezone.localtime().replace(
            hour=2, minute=0, second=0, microsecond=0
        )
        with patch("content.daily_mini_exam.istanbul_now", return_value=pre_open):
            body = self.client.get(self.url(), {"kpss_type": "lisans"}).json()

        self.assertFalse(body["isOpen"])
        self.assertGreater(len(body["leaderboard"]), 0)
        self.assertGreater(body["leaderboardParticipantCount"], 0)
        self.assertNotEqual(body["leaderboardDate"], body["examDate"])

    def test_duplicate_submit_does_not_change_score(self):
        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam = self.client.get(self.url(), {"kpss_type": "lisans"}).json()
            answers = {qid: "A" for qid in exam["questionIds"]}
            self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": answers,
                    "duration_seconds": 10,
                },
                content_type="application/json",
                **self.auth(),
            )
            again = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": {qid: "B" for qid in exam["questionIds"]},
                    "duration_seconds": 10,
                },
                content_type="application/json",
                **self.auth(),
            )
        self.assertEqual(again.status_code, 200)
        self.assertEqual(again.json()["myAttempt"]["correct"], 20)

    def test_first_day_guest_can_submit(self):
        guest = AppUser.objects.create(
            google_sub="guest-first-day",
            email="guest-first@guest.hedefkamu.app",
            display_name="Misafir",
            api_token="guest-token-1",
            is_anonymous=True,
        )
        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth(guest)
            ).json()
            self.assertFalse(exam["guestLoginRequired"])
            response = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": {qid: "A" for qid in exam["questionIds"]},
                    "duration_seconds": 120,
                },
                content_type="application/json",
                **self.auth(guest),
            )
        self.assertEqual(response.status_code, 201)

    def test_later_day_guest_must_sign_in(self):
        guest = AppUser.objects.create(
            google_sub="guest-later-day",
            email="guest-later@guest.hedefkamu.app",
            display_name="Misafir",
            api_token="guest-token-2",
            is_anonymous=True,
        )
        AppUser.objects.filter(pk=guest.pk).update(
            created_at=timezone.now() - timedelta(days=2),
        )
        guest.refresh_from_db()
        self.assertTrue(guest_login_required(guest, timezone.localdate()))
        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam = self.client.get(
                self.url(), {"kpss_type": "lisans"}, **self.auth(guest)
            ).json()
            self.assertTrue(exam["guestLoginRequired"])
            response = self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": {qid: "A" for qid in exam["questionIds"]},
                    "duration_seconds": 120,
                },
                content_type="application/json",
                **self.auth(guest),
            )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["code"], "guest_login_required")

    def test_demo_users_excluded_from_leaderboard(self):
        from content.models import DailyMiniExamAttempt
        from content.daily_mini_exam import exam_date_for, get_or_create_today_exam

        demo = AppUser.objects.create(
            google_sub="demo-mini-leader-99",
            email="demo.mini99@hedefkamu.app",
            display_name="Demo Test",
            api_token="demo-token",
            is_anonymous=False,
        )
        today = exam_date_for()
        exam = get_or_create_today_exam("lisans")
        DailyMiniExamAttempt.objects.create(
            user=demo,
            exam_date=today,
            kpss_type="lisans",
            correct=19,
            wrong=1,
            blank=0,
            total=20,
            duration_seconds=300,
            wrong_question_ids=[],
            answers={},
        )

        open_now = self._open_now()
        with patch("content.daily_mini_exam.istanbul_now", return_value=open_now):
            exam_json = self.client.get(self.url(), {"kpss_type": "lisans"}).json()
            answers = {qid: "A" for qid in exam_json["questionIds"]}
            self.client.post(
                self.url(),
                data={
                    "kpss_type": "lisans",
                    "answers": answers,
                    "duration_seconds": 400,
                },
                content_type="application/json",
                **self.auth(),
            )
            body = self.client.get(self.url(), {"kpss_type": "lisans"}).json()

        self.assertEqual(body["participantCount"], 1)
        self.assertEqual(body["leaderboardParticipantCount"], 1)
        self.assertEqual(len(body["leaderboard"]), 1)
        self.assertEqual(body["leaderboard"][0]["userId"], str(self.user.pk))
        demo_ids = {row["userId"] for row in body["leaderboard"]}
        self.assertNotIn(str(demo.pk), demo_ids)
