from django.urls import path

from .views import (
    AnnouncementListView,
    ContentCatalogView,
    ContentPackVersionView,
    ContentPackView,
    CurriculumView,
    DeviceTokenView,
    GoogleAuthView,
    HealthView,
    MeMessagesView,
    MeView,
    PublishedQuestionsView,
    PublishedTestsView,
    QuestionRatingView,
    DailyMiniExamView,
    ExamTypeListView,
    PromoRedeemView,
    TestQuestionsView,
)

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("pack/", ContentPackView.as_view(), name="content-pack"),
    path("pack/version/", ContentPackVersionView.as_view(), name="content-pack-version"),
    path("catalog/", ContentCatalogView.as_view(), name="content-catalog"),
    path("curriculum/", CurriculumView.as_view(), name="curriculum"),
    path("questions/", PublishedQuestionsView.as_view(), name="questions"),
    path(
        "questions/<str:public_id>/rating/",
        QuestionRatingView.as_view(),
        name="question-rating",
    ),
    path("tests/", PublishedTestsView.as_view(), name="tests"),
    path(
        "tests/<str:test_id>/questions/",
        TestQuestionsView.as_view(),
        name="test-questions",
    ),
    path("announcements/", AnnouncementListView.as_view(), name="announcements"),
    path("device-tokens/", DeviceTokenView.as_view(), name="device-tokens"),
    path("auth/google/", GoogleAuthView.as_view(), name="auth-google"),
    path("me/", MeView.as_view(), name="me"),
    path("me/messages/", MeMessagesView.as_view(), name="me-messages"),
    path("daily-mini-exam/", DailyMiniExamView.as_view(), name="daily-mini-exam"),
    path("promo/redeem/", PromoRedeemView.as_view(), name="promo-redeem"),
    path("exam-types/", ExamTypeListView.as_view(), name="exam-types"),
]
