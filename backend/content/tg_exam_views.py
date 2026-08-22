"""Türkiye Geneli deneme API uç noktaları."""

from __future__ import annotations

from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView

from .auth import get_user_from_request
from .models import Question, TgExam, TgExamAttempt
from .serializers import QuestionSerializer
from .test_grouping import order_questions_keeping_scenarios
from .tg_exam import (
    VALID_KPSS_TYPES,
    exam_to_dict,
    finalize_due_tg_exams,
    grade_attempt,
    kpss_net,
    refresh_exam_rankings,
)


class TgExamListView(APIView):
    """GET /api/v1/tg-exams/ — kullanıcının TG deneme listesi."""

    authentication_classes = []
    permission_classes = []

    def get(self, request):
        finalize_due_tg_exams(send_push=True)
        kpss_type = (request.query_params.get("kpss_type") or "lisans").strip()
        if kpss_type not in VALID_KPSS_TYPES:
            return Response({"detail": "Geçersiz kpss_type."}, status=400)

        user = get_user_from_request(request)
        exams = TgExam.objects.filter(is_published=True, kpss_type=kpss_type)
        attempts_by_exam: dict[int, TgExamAttempt] = {}
        if user is not None:
            attempts = TgExamAttempt.objects.filter(
                user=user,
                exam__in=exams,
            )
            attempts_by_exam = {a.exam_id: a for a in attempts}

        now = timezone.now()
        rows = [
            exam_to_dict(
                exam,
                attempt=attempts_by_exam.get(exam.pk),
                now=now,
            )
            for exam in exams
        ]
        return Response({"exams": rows})


class TgExamDetailView(APIView):
    """GET /api/v1/tg-exams/<id>/ — karşılama ekranı detayı."""

    authentication_classes = []
    permission_classes = []

    def get(self, request, exam_id: int):
        finalize_due_tg_exams(send_push=True)
        exam = get_object_or_404(TgExam, pk=exam_id, is_published=True)
        exam.refresh_from_db()
        user = get_user_from_request(request)
        attempt = None
        if user is not None:
            attempt = TgExamAttempt.objects.filter(user=user, exam=exam).first()
        return Response(exam_to_dict(exam, attempt=attempt))


class TgExamQuestionsView(APIView):
    """GET /api/v1/tg-exams/<id>/questions/ — deneme soruları."""

    authentication_classes = []
    permission_classes = []

    def get(self, request, exam_id: int):
        exam = get_object_or_404(TgExam, pk=exam_id, is_published=True)
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)

        now = timezone.now()
        if now < exam.start_at:
            return Response({"detail": "Deneme henüz başlamadı."}, status=403)
        if now >= exam.end_at:
            return Response(
                {"detail": "Deneme katılım süresi sona erdi."},
                status=403,
            )

        attempt = TgExamAttempt.objects.filter(user=user, exam=exam).first()
        if attempt is not None and attempt.is_submitted:
            return Response({"detail": "Deneme zaten gönderildi."}, status=409)

        question_ids = list(exam.question_ids or [])
        if not question_ids:
            return Response({"detail": "Deneme soruları henüz tanımlanmadı."}, status=409)

        qs = Question.objects.filter(
            public_id__in=question_ids,
            is_published=True,
        ).select_related("topic", "topic__subject", "scenario")
        ordered = order_questions_keeping_scenarios(qs, question_ids)
        data = QuestionSerializer(ordered, many=True, context={"request": request}).data
        return Response(
            {
                "examId": exam.pk,
                "title": exam.title,
                "durationMinutes": exam.duration_minutes,
                "questionIds": question_ids,
                "questions": data,
            }
        )


class TgExamProgressView(APIView):
    """POST /api/v1/tg-exams/<id>/progress/ — oturum ilerlemesi."""

    authentication_classes = []
    permission_classes = []

    def post(self, request, exam_id: int):
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)

        exam = get_object_or_404(TgExam, pk=exam_id, is_published=True)
        now = timezone.now()
        if now < exam.start_at or now >= exam.end_at:
            return Response({"detail": "Deneme aktif değil."}, status=403)

        attempt = TgExamAttempt.objects.filter(user=user, exam=exam).first()
        if attempt is not None and attempt.is_submitted:
            return Response({"detail": "Deneme zaten gönderildi."}, status=409)

        raw_answers = request.data.get("answers") or {}
        if not isinstance(raw_answers, dict):
            return Response({"detail": "answers nesne olmalı."}, status=400)

        current_index = int(request.data.get("current_index") or request.data.get("currentIndex") or 0)
        elapsed = int(
            request.data.get("elapsed_seconds")
            or request.data.get("elapsedSeconds")
            or 0
        )

        if attempt is None:
            attempt = TgExamAttempt.objects.create(
                user=user,
                exam=exam,
                answers=raw_answers,
                current_index=max(0, current_index),
                elapsed_seconds=max(0, elapsed),
            )
        else:
            attempt.answers = raw_answers
            attempt.current_index = max(0, current_index)
            attempt.elapsed_seconds = max(0, elapsed)
            attempt.save(
                update_fields=["answers", "current_index", "elapsed_seconds"]
            )

        return Response(exam_to_dict(exam, attempt=attempt))


class TgExamSubmitView(APIView):
    """POST /api/v1/tg-exams/<id>/submit/ — denemeyi bitir ve puanla."""

    authentication_classes = []
    permission_classes = []

    def post(self, request, exam_id: int):
        user = get_user_from_request(request)
        if user is None:
            return Response({"detail": "Oturum gerekli."}, status=401)

        exam = get_object_or_404(TgExam, pk=exam_id, is_published=True)
        now = timezone.now()
        if now < exam.start_at:
            return Response({"detail": "Deneme henüz başlamadı."}, status=403)
        if now >= exam.end_at:
            return Response(
                {"detail": "Deneme katılım süresi sona erdi."},
                status=403,
            )

        attempt = TgExamAttempt.objects.filter(user=user, exam=exam).first()
        if attempt is not None and attempt.is_submitted:
            return Response(exam_to_dict(exam, attempt=attempt), status=200)

        raw_answers = request.data.get("answers") or {}
        if not isinstance(raw_answers, dict):
            return Response({"detail": "answers nesne olmalı."}, status=400)

        duration = int(
            request.data.get("duration_seconds")
            or request.data.get("durationSeconds")
            or (attempt.elapsed_seconds if attempt else 0)
        )
        question_ids = list(exam.question_ids or [])
        correct, wrong, blank, graded, subject_nets = grade_attempt(
            question_ids, raw_answers
        )
        net = kpss_net(correct, wrong)

        if attempt is None:
            attempt = TgExamAttempt(user=user, exam=exam)

        attempt.answers = graded
        attempt.correct = correct
        attempt.wrong = wrong
        attempt.blank = blank
        attempt.net = net
        attempt.subject_nets = subject_nets
        attempt.duration_seconds = max(0, duration)
        attempt.is_submitted = True
        attempt.submitted_at = now
        attempt.save()

        refresh_exam_rankings(exam.pk)
        attempt.refresh_from_db()

        return Response(exam_to_dict(exam, attempt=attempt), status=201)
