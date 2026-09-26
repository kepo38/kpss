from django.apps import AppConfig
from django.contrib import admin


class ContentConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "content"
    verbose_name = "İçerik"

    def ready(self) -> None:
        # Sinyaller: soru/test değişince içerik sürümü + FCM
        from . import revision  # noqa: F401
        from .tg_exam import signals  # noqa: F401

        _patch_admin_context()


def _patch_admin_context() -> None:
    original = admin.site.each_context

    def each_context(request):
        ctx = original(request)
        try:
            from .models import Question, Subject, Topic, TopicTest

            ctx["kpss_stats"] = {
                "subjects": Subject.objects.filter(is_active=True).count(),
                "topics": Topic.objects.filter(is_active=True).count(),
                "questions": Question.objects.count(),
                "published_questions": Question.objects.filter(
                    is_published=True
                ).count(),
                "tests": TopicTest.objects.count(),
                "published_tests": TopicTest.objects.filter(
                    is_published=True
                ).count(),
            }
        except Exception:
            ctx["kpss_stats"] = {
                "subjects": 0,
                "topics": 0,
                "questions": 0,
                "published_questions": 0,
                "tests": 0,
                "published_tests": 0,
            }
        return ctx

    admin.site.each_context = each_context  # type: ignore[method-assign]
