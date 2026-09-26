"""TG deneme API URL'leri — test/deneme paketi rotalarından ayrı."""

from django.urls import path

from .api_views import (
    TgExamDetailView,
    TgExamListView,
    TgExamProgressView,
    TgExamQuestionsView,
    TgExamSubmitView,
)

urlpatterns = [
    path("tg-exams/", TgExamListView.as_view(), name="tg-exams"),
    path("tg-exams/<int:exam_id>/", TgExamDetailView.as_view(), name="tg-exam-detail"),
    path(
        "tg-exams/<int:exam_id>/questions/",
        TgExamQuestionsView.as_view(),
        name="tg-exam-questions",
    ),
    path(
        "tg-exams/<int:exam_id>/progress/",
        TgExamProgressView.as_view(),
        name="tg-exam-progress",
    ),
    path(
        "tg-exams/<int:exam_id>/submit/",
        TgExamSubmitView.as_view(),
        name="tg-exam-submit",
    ),
]
