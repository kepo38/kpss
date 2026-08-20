from django.db.models import Avg, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.response import Response
from rest_framework.throttling import SimpleRateThrottle
from rest_framework.views import APIView

from .auth import (
    AuthError,
    get_user_from_request,
    heal_guest_display_name,
    resolve_google_claims,
    upsert_firebase_user,
    user_to_dict,
)
from .embeddings import similar_questions
from .models import (
    Announcement,
    get_mobile_ui_config,
    DailyMiniExamAttempt,
    ExamPack,
    ExamPackExam,
    ExamType,
    Question,
    QuestionAttempt,
    QuestionErrorReport,
    ERROR_REPORT_CATEGORY_CHOICES,
    QuestionRating,
    Subject,
    TopicLesson,
    TopicSummaryCard,
    TopicTest,
    TopicTestCompletion,
)
from .revision import get_content_version
from .special_tests import build_special_tests_payload
from .test_grouping import order_questions_keeping_scenarios
from .serializers import (
    AnnouncementSerializer,
    ContentCatalogSerializer,
    ContentPackSerializer,
    DeviceTokenSerializer,
    ExamPackListSerializer,
    ExamPackSerializer,
    QuestionSerializer,
    SubjectSerializer,
    TopicTestSerializer,
    UserMessageSerializer,
)


class HealthView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        return Response({"status": "ok", "service": "kpss-odak-content"})


class ContentPackView(APIView):
    """Yayınlanmış müfredat + soru + test + bilgi paketi (mobil sync)."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        subjects_qs = Subject.objects.filter(is_active=True).prefetch_related(
            "topics"
        )
        questions = (
            Question.objects.filter(is_published=True, topic__is_active=True)
            .select_related("topic", "topic__subject", "scenario")
            .order_by("public_id")
        )
        tests = (
            TopicTest.objects.filter(is_published=True, topic__is_active=True)
            .prefetch_related("questions")
            .select_related("topic")
            .order_by("-created_at")
        )
        lessons = (
            TopicLesson.objects.filter(
                is_published=True, topic__is_active=True
            )
            .select_related("topic")
            .order_by("sort_order", "id")
        )
        summary_cards = (
            TopicSummaryCard.objects.filter(
                is_published=True, topic__is_active=True
            )
            .select_related("topic", "topic__subject")
            .order_by("sort_order", "id")
        )

        payload = {
            "version": get_content_version(),
            "generatedAt": timezone.now(),
            "subjects": subjects_qs,
            "questions": questions,
            "tests": tests,
            "lessons": lessons,
            "summaryCards": summary_cards,
        }
        data = ContentPackSerializer(payload, context={"request": request}).data
        return Response(data)


class ContentCatalogView(APIView):
    """Hafif içerik kataloğu — test listesi ve ders yapısı; soru gövdeleri yok."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        subjects_qs = Subject.objects.filter(is_active=True).prefetch_related(
            "topics"
        )
        tests = (
            TopicTest.objects.filter(is_published=True, topic__is_active=True)
            .prefetch_related("questions")
            .select_related("topic")
            .order_by("-created_at")
        )
        lessons = (
            TopicLesson.objects.filter(
                is_published=True, topic__is_active=True
            )
            .select_related("topic")
            .order_by("sort_order", "id")
        )
        summary_cards = (
            TopicSummaryCard.objects.filter(
                is_published=True, topic__is_active=True
            )
            .select_related("topic", "topic__subject")
            .order_by("sort_order", "id")
        )
        payload = {
            "version": get_content_version(),
            "generatedAt": timezone.now(),
            "subjects": subjects_qs,
            "tests": tests,
            "lessons": lessons,
            "summaryCards": summary_cards,
        }
        data = ContentCatalogSerializer(payload, context={"request": request}).data
        return Response(data)


class ContentPackVersionView(APIView):
    """Hafif sürüm kontrolü — paket indirmeden güncelleme var mı?"""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        return Response(
            {
                "version": get_content_version(),
                "generatedAt": timezone.now(),
            }
        )


class PublishedQuestionsView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        qs = Question.objects.filter(
            is_published=True,
            topic__is_active=True,
        ).select_related("topic", "topic__subject", "scenario")
        ids_raw = (request.query_params.get("ids") or "").strip()
        if ids_raw:
            ids = [part.strip() for part in ids_raw.split(",") if part.strip()]
            if ids:
                qs = qs.filter(public_id__in=ids)
        return Response(
            QuestionSerializer(qs, many=True, context={"request": request}).data
        )


class SimilarQuestionsView(APIView):
    """Yanlış soruya anlamsal olarak yakın yayınlı sorular."""

    authentication_classes = []
    permission_classes = []

    def get(self, request, public_id: str):
        question = get_object_or_404(
            Question,
            public_id=public_id,
            is_published=True,
            topic__is_active=True,
        )
        try:
            threshold = float(request.query_params.get("threshold") or 0.75)
        except (TypeError, ValueError):
            threshold = 0.75
        threshold = max(0.0, min(threshold, 1.0))
        scored = similar_questions(question, limit=5, threshold=threshold)
        payload = []
        for score, candidate in scored:
            item = QuestionSerializer(
                candidate, context={"request": request}
            ).data
            item["similarity"] = round(float(score), 4)
            payload.append(item)
        return Response(
            {
                "sourceId": question.public_id,
                "questions": payload,
            }
        )


class TestQuestionsView(APIView):
    """Tek testin sorularını anlık döner — mobil test başlangıcında."""

    authentication_classes = []
    permission_classes = []

    def get(self, request, test_id: str):
        test = get_object_or_404(
            TopicTest,
            public_id=test_id,
            is_published=True,
            topic__is_active=True,
        )
        questions = order_questions_keeping_scenarios(
            [
                q
                for q in test.questions.select_related("scenario").all()
                if q.is_published and q.topic_id == test.topic_id
            ]
        )
        return Response(
            {
                "testId": test.public_id,
                "title": test.title,
                "questionCount": len(questions),
                "questions": QuestionSerializer(
                    questions,
                    many=True,
                    context={"request": request},
                ).data,
            }
        )


def _require_permanent_user(request):
    """Google ile bağlı hesap; misafir Firebase oturumu reddedilir."""
    user = get_user_from_request(request)
    if user is None:
        return None, Response({"detail": "Oturum gerekli."}, status=401)
    if user.is_anonymous:
        return None, Response(
            {"detail": "Google hesabı gerekli."},
            status=401,
        )
    return user, None


class TestAttemptView(APIView):
    """Store a logged-in user's first answers for a published topic test."""

    authentication_classes = []
    permission_classes = []

    def post(self, request, test_id: str):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error

        test = get_object_or_404(
            TopicTest.objects.prefetch_related("questions"),
            public_id=test_id,
            is_published=True,
            topic__is_active=True,
        )
        raw_answers = request.data.get("answers")
        if not isinstance(raw_answers, dict):
            return Response({"detail": "answers nesne olmalı."}, status=400)

        questions = {
            question.public_id: question
            for question in test.questions.all()
            if question.is_published and question.topic_id == test.topic_id
        }
        accepted = ignored = 0
        for public_id, question in questions.items():
            selected = str(raw_answers.get(public_id) or "").strip().upper()[:1]
            if not selected:
                outcome = QuestionAttempt.OUTCOME_BLANK
            elif selected == question.correct_option:
                outcome = QuestionAttempt.OUTCOME_CORRECT
            else:
                outcome = QuestionAttempt.OUTCOME_WRONG
            if QuestionAttempt.record_first_answer(
                question=question,
                user=user,
                outcome=outcome,
                selected_option=selected,
            ):
                accepted += 1
            else:
                ignored += 1

        if request.data.get("completed") is True and len(questions) > 0:
            TopicTestCompletion.objects.get_or_create(user=user, topic_test=test)

        return Response(
            {
                "accepted": accepted,
                "ignored": ignored,
                "questionCount": len(questions),
            }
        )


def _attempt_stats_payload(question: Question) -> dict:
    option_counts = {
        "A": question.option_a_count,
        "B": question.option_b_count,
        "C": question.option_c_count,
        "D": question.option_d_count,
        "E": question.option_e_count,
    }
    solved_count = sum(option_counts.values())
    percentages = None
    if solved_count >= 100:
        percentages = {
            option: round(count / solved_count * 100, 1)
            for option, count in option_counts.items()
        }
    return {
        "attemptCount": question.attempt_count,
        "solvedCount": solved_count,
        "optionPercentages": percentages,
    }


class QuestionAttemptView(APIView):
    """Kaydedilen ilk şık ve aday istatistikleri için anlık uç nokta."""

    authentication_classes = []
    permission_classes = []

    def post(self, request, public_id: str):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error

        test_id = str(request.data.get("testId") or "").strip()
        selected_option = str(request.data.get("selectedOption") or "").strip().upper()
        if not test_id:
            return Response({"detail": "testId gerekli."}, status=400)
        if selected_option not in {"A", "B", "C", "D", "E"}:
            return Response({"detail": "Geçerli bir şık gerekli."}, status=400)

        question = get_object_or_404(
            Question,
            public_id=public_id,
            is_published=True,
            topic__is_active=True,
        )
        test = get_object_or_404(
            TopicTest.objects.filter(
                public_id=test_id,
                is_published=True,
                topic_id=question.topic_id,
                questions=question,
            )
        )
        outcome = (
            QuestionAttempt.OUTCOME_CORRECT
            if selected_option == question.correct_option
            else QuestionAttempt.OUTCOME_WRONG
        )
        accepted = QuestionAttempt.record_first_answer(
            question=question,
            user=user,
            outcome=outcome,
            selected_option=selected_option,
        )
        question.refresh_from_db()
        return Response(
            {
                "accepted": accepted,
                "testId": test.public_id,
                **_attempt_stats_payload(question),
            }
        )


def _rating_payload(question: Question, user) -> dict:
    aggregate = question.ratings.aggregate(
        average=Avg("stars"),
        count=Count("id"),
    )
    user_rating = (
        question.ratings.filter(user=user).values_list("stars", flat=True).first()
    )
    average = aggregate["average"]
    return {
        "userRating": user_rating,
        "averageRating": round(float(average), 2) if average is not None else None,
        "ratingCount": aggregate["count"],
    }


class QuestionRatingThrottle(SimpleRateThrottle):
    scope = "question_rating"

    def get_cache_key(self, request, view):
        user = get_user_from_request(request)
        if user is None:
            return None
        return self.cache_format % {
            "scope": self.scope,
            "ident": user.pk,
        }


class QuestionRatingView(APIView):
    """Oturumdaki öğrencinin tekil ve değiştirilebilir soru puanı."""

    authentication_classes = []
    permission_classes = []
    throttle_classes = [QuestionRatingThrottle]

    def _user(self, request):
        return get_user_from_request(request)

    def get(self, request, public_id: str):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error
        question = get_object_or_404(
            Question,
            public_id=public_id,
            is_published=True,
        )
        return Response(_rating_payload(question, user))

    def put(self, request, public_id: str):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error

        raw_stars = request.data.get("stars")
        if isinstance(raw_stars, bool) or not isinstance(raw_stars, (int, str)):
            return Response({"detail": "Yıldız 1–5 arasında olmalı."}, status=400)
        try:
            normalized = str(raw_stars).strip()
            if normalized not in {"1", "2", "3", "4", "5"}:
                raise ValueError
            stars = int(normalized)
        except (TypeError, ValueError):
            return Response({"detail": "Yıldız 1–5 arasında olmalı."}, status=400)

        question = get_object_or_404(
            Question,
            public_id=public_id,
            is_published=True,
        )
        QuestionRating.objects.update_or_create(
            question=question,
            user=user,
            defaults={"stars": stars},
        )
        return Response(_rating_payload(question, user))


class QuestionErrorReportThrottle(SimpleRateThrottle):
    scope = "question_error_report"

    def get_cache_key(self, request, view):
        user = get_user_from_request(request)
        if user is None:
            return None
        return self.cache_format % {
            "scope": self.scope,
            "ident": user.pk,
        }


MIN_COMPLETED_TESTS_FOR_ERROR_REPORT = 5
MIN_COMPLETED_TESTS_FOR_ERROR_REPORT_PREMIUM = 3


def _min_tests_for_error_report(user) -> int:
    if user is not None and getattr(user, "premium_active", False):
        return MIN_COMPLETED_TESTS_FOR_ERROR_REPORT_PREMIUM
    return MIN_COMPLETED_TESTS_FOR_ERROR_REPORT


def _user_completed_topic_test_count(user, min_required: int | None = None) -> int:
    needed = min_required if min_required is not None else _min_tests_for_error_report(user)
    explicit = TopicTestCompletion.objects.filter(user=user).count()
    if explicit >= needed:
        return explicit

    completed = explicit
    tests = TopicTest.objects.filter(
        is_published=True,
        topic__is_active=True,
    ).prefetch_related("questions")
    for test in tests:
        question_pks = [
            question.pk
            for question in test.questions.all()
            if question.is_published
        ]
        if not question_pks:
            continue
        answered = (
            QuestionAttempt.objects.filter(
                user=user,
                question_id__in=question_pks,
            )
            .values("question_id")
            .distinct()
            .count()
        )
        if answered >= len(question_pks):
            completed += 1
            if completed >= needed:
                break
    return completed


def _error_report_payload(
    report: QuestionErrorReport | None,
    *,
    daily_limit_reached: bool,
    user=None,
) -> dict:
    min_required = _min_tests_for_error_report(user)
    tests_completed = (
        _user_completed_topic_test_count(user, min_required) if user else 0
    )
    tests_ok = tests_completed >= min_required
    return {
        "reported": report is not None,
        "category": report.category if report else None,
        "status": report.status if report else None,
        "createdAt": report.created_at.isoformat() if report else None,
        "dailyLimitReached": daily_limit_reached,
        "testsCompleted": tests_completed,
        "minTestsRequired": min_required,
        "testsRequirementMet": tests_ok,
        "canReport": report is None and not daily_limit_reached and tests_ok,
    }


def _user_reported_today(user) -> bool:
    now = timezone.localtime()
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    return QuestionErrorReport.objects.filter(
        user=user,
        created_at__gte=start,
    ).exists()


class QuestionErrorReportView(APIView):
    """Öğrencinin soru hata bildirimi (günde en fazla 1)."""

    authentication_classes = []
    permission_classes = []
    throttle_classes = [QuestionErrorReportThrottle]

    def _user(self, request):
        return get_user_from_request(request)

    def get(self, request, public_id: str):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error
        question = get_object_or_404(
            Question,
            public_id=public_id,
            is_published=True,
        )
        report = QuestionErrorReport.objects.filter(
            question=question, user=user
        ).first()
        daily_limit = _user_reported_today(user)
        return Response(
            _error_report_payload(
                report,
                daily_limit_reached=daily_limit,
                user=user,
            )
        )

    def post(self, request, public_id: str):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error

        category = (request.data.get("category") or "").strip()
        valid = {c[0] for c in ERROR_REPORT_CATEGORY_CHOICES}
        if category not in valid:
            return Response(
                {"detail": "Geçerli bir bildirim türü seçin."},
                status=400,
            )

        note = (request.data.get("note") or "").strip()[:2000]

        question = get_object_or_404(
            Question,
            public_id=public_id,
            is_published=True,
        )
        existing = QuestionErrorReport.objects.filter(
            question=question, user=user
        ).first()
        if existing is not None:
            return Response(
                _error_report_payload(
                    existing,
                    daily_limit_reached=True,
                    user=user,
                )
            )

        min_required = _min_tests_for_error_report(user)
        completed_count = _user_completed_topic_test_count(user, min_required)
        if completed_count < min_required:
            return Response(
                {
                    "detail": (
                        f"En az {min_required} test "
                        "bitirmeden hata bildirimi yapamazsınız."
                    ),
                    "testsCompleted": completed_count,
                    "minTestsRequired": min_required,
                    "testsRequirementMet": False,
                    "reported": False,
                    "canReport": False,
                },
                status=403,
            )

        if _user_reported_today(user):
            return Response(
                {
                    "detail": "Günde yalnızca 1 hata bildirimi yapabilirsiniz.",
                    "dailyLimitReached": True,
                    "reported": False,
                    "canReport": False,
                },
                status=429,
            )

        report = QuestionErrorReport.objects.create(
            question=question,
            user=user,
            category=category,
            note=note,
            status="open",
        )
        payload = _error_report_payload(
            report,
            daily_limit_reached=True,
            user=user,
        )
        payload["created"] = True
        return Response(payload, status=201)


class PublishedTestsView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        qs = TopicTest.objects.filter(is_published=True).prefetch_related(
            "questions"
        )
        return Response(TopicTestSerializer(qs, many=True).data)


class CurriculumView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        qs = Subject.objects.filter(is_active=True).prefetch_related("topics")
        return Response(SubjectSerializer(qs, many=True).data)


class MobileUiConfigView(APIView):
    """Mobil arayüz ayarları — ana sayfa promosyon balonu vb."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        cfg = get_mobile_ui_config()
        return Response(
            {
                "wrongNotebookBubbleEnabled": cfg.wrong_notebook_bubble_enabled,
                "wrongNotebookBubbleLabel": cfg.wrong_notebook_bubble_label,
                "updatedAt": cfg.updated_at,
            }
        )


class AnnouncementListView(APIView):
    """Yayınlanmış duyurular (uygulama içi liste)."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        qs = Announcement.objects.filter(is_published=True).order_by("-created_at")[
            :50
        ]
        return Response(
            AnnouncementSerializer(
                qs, many=True, context={"request": request}
            ).data
        )


class DeviceTokenView(APIView):
    """Mobil FCM jetonu kaydı / yenileme."""

    authentication_classes = []
    permission_classes = []

    def post(self, request):
        ser = DeviceTokenSerializer(
            data=request.data,
            context={"user": get_user_from_request(request)},
        )
        if not ser.is_valid():
            return Response(ser.errors, status=400)
        obj = ser.save()
        return Response(
            {
                "ok": True,
                "platform": obj.platform,
                "topic": "kpss_duyuru",
            },
            status=201,
        )


class GoogleAuthView(APIView):
    """Google / Play Store hesabı ile giriş — id_token doğrular, AppUser oluşturur."""

    authentication_classes = []
    permission_classes = []

    def post(self, request):
        id_token = (
            request.data.get("id_token")
            or request.data.get("idToken")
            or ""
        )
        access_token = (
            request.data.get("access_token")
            or request.data.get("accessToken")
            or ""
        )
        try:
            claims = resolve_google_claims(
                id_token=str(id_token),
                access_token=str(access_token),
            )
            client_name = str(
                request.data.get("display_name")
                or request.data.get("isim")
                or ""
            ).strip()
            if client_name and not (claims.get("name") or "").strip():
                claims["name"] = client_name
            user = upsert_firebase_user(claims)
        except AuthError as exc:
            return Response({"detail": exc.message}, status=exc.status)
        except Exception:  # noqa: BLE001
            return Response({"detail": "Giriş başarısız."}, status=400)

        return Response(
            {
                "token": user.api_token,
                "user": user_to_dict(user),
            }
        )


class MeView(APIView):
    """Oturum açmış kullanıcı profili."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)
        heal_guest_display_name(user)
        return Response(user_to_dict(user))

    def patch(self, request):
        """Profil güncelle — şu an yalnızca görünen ad."""
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)

        raw = (
            request.data.get("isim")
            or request.data.get("display_name")
            or request.data.get("name")
        )
        if raw is None:
            return Response({"detail": "isim alanı gerekli."}, status=400)

        name = str(raw).strip()
        if not name:
            return Response({"detail": "Ad boş olamaz."}, status=400)
        if len(name) > 160:
            return Response(
                {"detail": "Ad en fazla 160 karakter olabilir."}, status=400
            )

        old_name = (user.display_name or "").strip()
        if old_name == name:
            return Response(user_to_dict(user))

        from datetime import timedelta

        if user.display_name_changed_at is not None:
            next_allowed = user.display_name_changed_at + timedelta(days=7)
            if timezone.now() < next_allowed:
                return Response(
                    {
                        "detail": (
                            "Ad en fazla haftada bir kez değiştirilebilir. "
                            f"Tekrar deneme: {next_allowed.strftime('%d.%m.%Y %H:%M')}"
                        ),
                        "isimDegistirilebilirAt": next_allowed.isoformat(),
                    },
                    status=429,
                )

        user.display_name = name
        user.display_name_changed_at = timezone.now()
        user.save(
            update_fields=[
                "display_name",
                "display_name_changed_at",
                "updated_at",
            ]
        )
        return Response(user_to_dict(user))

    def delete(self, request):
        """Çıkış — API jetonunu geçersizleştir."""
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)
        from .auth import new_api_token

        user.api_token = new_api_token()
        user.save(update_fields=["api_token", "updated_at"])
        return Response({"ok": True})


class MeMessagesView(APIView):
    """Kullanıcıya özel admin mesajları."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)
        from .models import UserMessage

        qs = UserMessage.objects.filter(user=user).order_by("-created_at")[:100]
        return Response(UserMessageSerializer(qs, many=True).data)

    def patch(self, request):
        """Mesajı okundu işaretle — {\"id\": 1} veya {\"all\": true}."""
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)
        from .models import UserMessage

        if request.data.get("all") is True:
            updated = UserMessage.objects.filter(
                user=user, is_read=False
            ).update(is_read=True)
            return Response({"ok": True, "updated": updated})

        raw_id = request.data.get("id") or request.data.get("message_id")
        msg_id = int(raw_id) if raw_id is not None else None
        if msg_id is None:
            return Response({"detail": "id gerekli."}, status=400)
        updated = UserMessage.objects.filter(
            user=user, pk=msg_id, is_read=False
        ).update(is_read=True)
        return Response({"ok": True, "updated": updated})

    def delete(self, request):
        """Kullanıcı kendi mesajını siler — {\"id\": 1}."""
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)
        from .models import UserMessage

        raw_id = request.data.get("id") or request.data.get("message_id")
        if raw_id is None:
            raw_id = request.query_params.get("id")
        try:
            msg_id = int(raw_id)
        except (TypeError, ValueError):
            return Response({"detail": "id gerekli."}, status=400)

        deleted, _ = UserMessage.objects.filter(user=user, pk=msg_id).delete()
        if deleted == 0:
            return Response({"detail": "Mesaj bulunamadı."}, status=404)
        return Response({"ok": True})


class DailyMiniExamView(APIView):
    """Günün 20 soruluk ücretsiz mini denemesi ve liderlik tablosu."""

    authentication_classes = []
    permission_classes = []

    def _kpss_type(self, request) -> str | None:
        from .daily_mini_exam import VALID_KPSS_TYPES

        raw = (
            request.query_params.get("kpss_type")
            or request.data.get("kpss_type")
            or "lisans"
        )
        value = str(raw).strip()
        if value not in VALID_KPSS_TYPES:
            return None
        return value

    def _payload(self, request, kpss_type: str) -> dict:
        from .daily_mini_exam import (
            attempt_counts_for_ranking,
            get_or_create_today_exam,
            guest_login_required,
            is_exam_open,
            leaderboard_rows,
            rank_for_user,
            seconds_until_deadline,
            window_bounds,
        )

        now, opens_at, closes_at = window_bounds()
        exam = get_or_create_today_exam(kpss_type, now=now)
        user = get_user_from_request(request)
        my_attempt = None
        my_rank = None
        if user is not None:
            attempt = DailyMiniExamAttempt.objects.filter(
                user=user,
                exam_date=exam.exam_date,
                kpss_type=kpss_type,
            ).first()
            if attempt is not None and attempt_counts_for_ranking(attempt):
                my_rank, _ = rank_for_user(
                    exam.exam_date, kpss_type, user.pk
                )
                my_attempt = {
                    "correct": attempt.correct,
                    "wrong": attempt.wrong,
                    "blank": attempt.blank,
                    "total": attempt.total,
                    "durationSeconds": attempt.duration_seconds,
                    "wrongQuestionIds": attempt.wrong_question_ids,
                    "rank": my_rank,
                    "completedAt": attempt.completed_at.isoformat(),
                }

        from .daily_mini_exam import attempts_for_leaderboard

        participant_count = attempts_for_leaderboard(
            exam.exam_date, kpss_type
        ).count()

        # 00:00–06:00 arası kürsüde dünün liderleri gösterilir.
        leaderboard_date = exam.exam_date
        if now < opens_at:
            from datetime import timedelta

            leaderboard_date = exam.exam_date - timedelta(days=1)
        leaderboard_participant_count = attempts_for_leaderboard(
            leaderboard_date, kpss_type
        ).count()

        return {
            "examDate": exam.exam_date.isoformat(),
            "kpssType": kpss_type,
            "isOpen": is_exam_open(now),
            "opensAt": opens_at.isoformat(),
            "closesAt": closes_at.isoformat(),
            "secondsRemaining": seconds_until_deadline(now),
            "questionIds": exam.question_ids,
            "questionCount": len(exam.question_ids),
            "participantCount": participant_count,
            "leaderboardDate": leaderboard_date.isoformat(),
            "leaderboardParticipantCount": leaderboard_participant_count,
            "myAttempt": my_attempt,
            "leaderboard": leaderboard_rows(leaderboard_date, kpss_type),
            "guestLoginRequired": guest_login_required(user, exam.exam_date),
        }

    def get(self, request):
        kpss_type = self._kpss_type(request)
        if kpss_type is None:
            return Response({"detail": "Geçersiz kpss_type."}, status=400)
        return Response(self._payload(request, kpss_type))

    def post(self, request):
        from .daily_mini_exam import (
            OPENS_HOUR,
            QUESTION_COUNT,
            attempt_counts_for_ranking,
            get_or_create_today_exam,
            guest_login_required,
            is_exam_open,
        )

        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)

        kpss_type = self._kpss_type(request)
        if kpss_type is None:
            return Response({"detail": "Geçersiz kpss_type."}, status=400)

        if not is_exam_open():
            return Response(
                {"detail": f"Günün mini denemesi kapalı. {OPENS_HOUR:02d}:00–00:00 arasında çözülür."},
                status=403,
            )

        exam = get_or_create_today_exam(kpss_type)
        if guest_login_required(user, exam.exam_date):
            return Response(
                {
                    "detail": "Misafir yalnızca ilk gün denemeye katılabilir. Profil’den giriş yapın.",
                    "code": "guest_login_required",
                    "guestLoginRequired": True,
                },
                status=403,
            )
        expected_ids = list(exam.question_ids)
        if len(expected_ids) < QUESTION_COUNT:
            return Response(
                {"detail": "Bugün için yeterli soru henüz yayınlanmadı."},
                status=409,
            )

        existing = DailyMiniExamAttempt.objects.filter(
            user=user,
            exam_date=exam.exam_date,
            kpss_type=kpss_type,
        ).first()
        if existing is not None and attempt_counts_for_ranking(existing):
            return Response(self._payload(request, kpss_type), status=200)
        if existing is not None:
            existing.delete()

        raw_answers = request.data.get("answers") or {}
        if not isinstance(raw_answers, dict):
            return Response({"detail": "answers nesne olmalı."}, status=400)

        questions = {
            q.public_id: q
            for q in Question.objects.filter(public_id__in=expected_ids)
        }
        correct = wrong = blank = 0
        wrong_ids: list[str] = []
        graded: dict[str, str] = {}
        for qid in expected_ids:
            question = questions.get(qid)
            selected = str(raw_answers.get(qid) or "").strip().upper()
            if not selected:
                blank += 1
                continue
            graded[qid] = selected[:1]
            if question is None:
                blank += 1
                continue
            if selected[:1] == question.correct_option:
                correct += 1
            else:
                wrong += 1
                wrong_ids.append(qid)

        duration = request.data.get("duration_seconds") or request.data.get(
            "durationSeconds"
        )
        try:
            duration_seconds = max(0, int(duration or 0))
        except (TypeError, ValueError):
            duration_seconds = 0

        if correct + wrong <= 0:
            return Response(
                {"detail": "Sıralamaya girmek için en az bir soru işaretleyin."},
                status=400,
            )

        DailyMiniExamAttempt.objects.create(
            user=user,
            exam_date=exam.exam_date,
            kpss_type=kpss_type,
            correct=correct,
            wrong=wrong,
            blank=blank,
            total=len(expected_ids),
            duration_seconds=duration_seconds,
            wrong_question_ids=wrong_ids,
            answers=graded,
        )
        return Response(self._payload(request, kpss_type), status=201)


class DailyMiniPeriodRankingView(APIView):
    """Haftalık / aylık mini deneme sıralaması (toplam doğru + süre)."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        from .daily_mini_exam import VALID_KPSS_TYPES
        from .daily_mini_ranking import period_ranking_payload

        raw_period = (request.query_params.get("period") or "weekly").strip().lower()
        if raw_period not in ("weekly", "monthly"):
            return Response({"detail": "period=weekly|monthly gerekli."}, status=400)
        kpss_type = (request.query_params.get("kpss_type") or "lisans").strip()
        if kpss_type not in VALID_KPSS_TYPES:
            return Response({"detail": "Geçersiz kpss_type."}, status=400)
        user = get_user_from_request(request)
        user_id = user.pk if user is not None else None
        return Response(period_ranking_payload(raw_period, kpss_type, user_id))


class DailyMiniRewardHistoryView(APIView):
    """Geçmiş dönem kazananları — herkes görebilir."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        from .daily_mini_exam import VALID_KPSS_TYPES
        from .daily_mini_ranking import get_ranking_campaign, reward_history

        kpss_type = (request.query_params.get("kpss_type") or "lisans").strip()
        if kpss_type not in VALID_KPSS_TYPES:
            return Response({"detail": "Geçersiz kpss_type."}, status=400)
        try:
            limit = min(48, max(1, int(request.query_params.get("limit", "24"))))
        except (TypeError, ValueError):
            limit = 24
        campaign = get_ranking_campaign()
        return Response(
            {
                "rewardsVisible": campaign.rewards_visible,
                "weeklyEnabled": campaign.weekly_enabled,
                "monthlyEnabled": campaign.monthly_enabled,
                "rewardDays": {"1": 3, "2": 2, "3": 1},
                "periods": reward_history(kpss_type, limit=limit),
            }
        )


class PromoRedeemThrottle(SimpleRateThrottle):
    scope = "promo_redeem"

    def get_cache_key(self, request, view):
        user = get_user_from_request(request)
        if user is None:
            return None
        return self.cache_format % {
            "scope": self.scope,
            "ident": user.pk,
        }


class PromoRedeemView(APIView):
    """Promosyon kodu kullanımı — premium tanımlar."""

    authentication_classes = []
    permission_classes = []
    throttle_classes = [PromoRedeemThrottle]

    def post(self, request):
        user, error = _require_permanent_user(request)
        if error is not None:
            return error

        raw = request.data.get("code") or request.data.get("kod")
        if raw is None:
            return Response({"detail": "Promosyon kodu gerekli."}, status=400)
        raw = str(raw)[:32]

        from .promo import PromoError, redeem_promo_code

        try:
            result = redeem_promo_code(user=user, raw_code=str(raw))
        except PromoError as exc:
            return Response({"detail": exc.message}, status=exc.status)

        user.refresh_from_db()
        return Response(
            {
                "ok": True,
                "message": result.message,
                "code": result.promo_code.code,
                "premiumExpiresAt": result.premium_expires_at.isoformat(),
                "user": user_to_dict(user),
            }
        )


class ExamTypeListView(APIView):
    """Aktif sınav tipleri ve tarihleri — mobil sayaç kataloğu."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        items = ExamType.objects.filter(is_active=True)
        return Response({"examTypes": [item.to_api() for item in items]})


class ExamPackListView(APIView):
    """Yayınlanmış deneme paketleri — Dersler vitrini."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        exam_type = (request.query_params.get("exam_type") or "").strip()
        qs = ExamPack.objects.filter(is_published=True).select_related(
            "exam_type", "subject"
        )
        if exam_type:
            et = ExamType.objects.filter(slug=exam_type).only(
                "slug", "content_type"
            ).first()
            if et is not None and not et.slug.startswith("kpss"):
                # AGS/ALES/DGS hedefi — aynı müfredat (content_type) KPSS paketleri
                qs = qs.filter(exam_type__content_type=et.content_type)
            else:
                qs = qs.filter(exam_type__slug=exam_type)
        qs = qs.order_by("sort_order", "title")
        return Response(
            {
                "packs": ExamPackListSerializer(
                    qs,
                    many=True,
                    context={"request": request},
                ).data
            }
        )


class ExamPackDetailView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request, pack_id: str):
        pack = get_object_or_404(
            ExamPack.objects.select_related("exam_type", "subject").prefetch_related(
                "exams"
            ),
            public_id=pack_id,
            is_published=True,
        )
        return Response(
            ExamPackSerializer(
                pack,
                context={"request": request, "include_exams": True},
            ).data
        )


class ExamPackExamQuestionsView(APIView):
    """Paket içi tekil denemenin soruları — Google hesabı zorunlu."""

    authentication_classes = []
    permission_classes = []

    def get(self, request, pack_id: str, exam_index: int):
        user = get_user_from_request(request)
        if user is None or user.is_anonymous:
            return Response(
                {
                    "detail": "Deneme paketleri için Google ile giriş yapmalısınız.",
                    "googleRequired": True,
                },
                status=401,
            )

        pack = get_object_or_404(
            ExamPack,
            public_id=pack_id,
            is_published=True,
        )
        exam = get_object_or_404(
            ExamPackExam.objects.prefetch_related(
                "question_links__question__scenario",
                "question_links__question__topic",
            ),
            pack=pack,
            index=exam_index,
        )
        links = exam.question_links.select_related(
            "question__scenario", "question__topic"
        ).order_by("sort_order", "id")
        assigned = [
            link.question
            for link in links
            if link.question.is_published
        ]
        from .exam_pack_generator import ExamPackGeneratorError
        from .exam_pack_personalize import personalize_exam_questions

        try:
            questions = personalize_exam_questions(assigned, user)
        except ExamPackGeneratorError as exc:
            return Response({"detail": str(exc)}, status=409)

        questions = order_questions_keeping_scenarios(questions)
        return Response(
            {
                "packId": pack.public_id,
                "examIndex": exam.index,
                "title": exam.title,
                "timeLimitMinutes": pack.time_limit_minutes,
                "questionCount": len(questions),
                "questions": QuestionSerializer(
                    questions,
                    many=True,
                    context={"request": request},
                ).data,
            }
        )


class SpecialTestsView(APIView):
    """Harita vb. sanal özel test kategorileri — konu testlerini kirletmez."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        return Response(build_special_tests_payload())
