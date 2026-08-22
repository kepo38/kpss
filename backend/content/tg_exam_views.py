"""Geriye dönük import — yeni kod: content.tg_exam.api_views"""

from .tg_exam.api_views import (  # noqa: F401
    TgExamDetailView,
    TgExamListView,
    TgExamProgressView,
    TgExamQuestionsView,
    TgExamSubmitView,
)
