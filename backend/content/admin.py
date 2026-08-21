from django.contrib import admin, messages as dj_messages
from django.contrib.admin.helpers import ACTION_CHECKBOX_NAME
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import Group, User
from django.db.models import Avg, Count
from django.shortcuts import render
from unfold.admin import ModelAdmin, TabularInline
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .models import (
    Announcement,
    AppUser,
    DailyMiniExam,
    DailyMiniExamAttempt,
    DeviceToken,
    ExamType,
    ExamDistributionTemplate,
    ExamPack,
    ExamPackExam,
    ExamPackExamQuestion,
    MapTemplate,
    PromoCode,
    PromoCodeRedemption,
    Question,
    QuestionAttempt,
    QuestionRating,
    OcrIngestLog,
    QuestionErrorReport,
    Subject,
    Topic,
    TopicLesson,
    TopicSummaryCard,
    TopicTest,
    UserMessage,
)

# Auth — Unfold formları
admin.site.unregister(User)
admin.site.unregister(Group)


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm


@admin.register(Group)
class GroupAdmin(BaseGroupAdmin, ModelAdmin):
    pass


class TopicInline(TabularInline):
    model = Topic
    extra = 0
    fields = (
        "slug",
        "name",
        "sort_order",
        "questions_per_test",
        "is_active",
    )
    show_change_link = True
    tab = True


@admin.register(Subject)
class SubjectAdmin(ModelAdmin):
    list_display = ("name", "slug", "sort_order", "is_active")
    list_editable = ("sort_order", "is_active")
    list_filter_sheet = False
    search_fields = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}
    inlines = [TopicInline]
    list_display_links = ("name",)
    compressed_fields = True


@admin.register(MapTemplate)
class MapTemplateAdmin(ModelAdmin):
    list_display = ("title", "slug", "kind", "created_at")
    list_filter = ("kind",)
    search_fields = ("title", "slug", "description")
    prepopulated_fields = {"slug": ("title",)}
    readonly_fields = ("created_at",)

@admin.register(Topic)
class TopicAdmin(ModelAdmin):
    list_display = (
        "name",
        "subject",
        "slug",
        "questions_per_test",
        "is_active",
    )
    list_filter = ("subject", "is_active")
    search_fields = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}
    autocomplete_fields = ("subject",)
    list_filter_sheet = False
    compressed_fields = True


class RatingBandFilter(admin.SimpleListFilter):
    title = "ortalama yıldız"
    parameter_name = "rating_band"

    def lookups(self, request, model_admin):
        return (
            ("unrated", "Puansız"),
            ("1", "1,00–1,99"),
            ("2", "2,00–2,99"),
            ("3", "3,00–3,99"),
            ("4", "4,00–4,99"),
            ("5", "5 yıldız"),
        )

    def queryset(self, request, queryset):
        value = self.value()
        if value == "unrated":
            return queryset.filter(_rating_count=0)
        if value in {"1", "2", "3", "4"}:
            lower = int(value)
            return queryset.filter(
                _rating_average__gte=lower,
                _rating_average__lt=lower + 1,
            )
        if value == "5":
            return queryset.filter(_rating_average=5)
        return queryset


class MinimumVotesFilter(admin.SimpleListFilter):
    title = "oy sayısı"
    parameter_name = "min_votes"

    def lookups(self, request, model_admin):
        return (
            ("1", "En az 1 oy"),
            ("10", "En az 10 oy"),
            ("25", "En az 25 oy"),
            ("50", "En az 50 oy"),
        )

    def queryset(self, request, queryset):
        value = self.value()
        if value in {"1", "10", "25", "50"}:
            return queryset.filter(_rating_count__gte=int(value))
        return queryset


@admin.register(Question)
class QuestionAdmin(ModelAdmin):
    list_display = (
        "public_id",
        "topic",
        "subtopic",
        "correct_option",
        "difficulty",
        "attempt_count",
        "average_rating",
        "rating_count",
        "is_published",
        "created_at",
        "updated_at",
    )
    list_filter = (
        "is_published",
        "topic__subject",
        "topic",
        "difficulty",
        RatingBandFilter,
        MinimumVotesFilter,
    )
    search_fields = ("public_id", "stem", "subtopic")
    autocomplete_fields = ("topic",)
    readonly_fields = (
        "attempt_count",
        "correct_count",
        "wrong_count",
        "blank_count",
        "created_at",
        "updated_at",
    )
    list_filter_sheet = False
    compressed_fields = True
    warn_unsaved_form = True
    fieldsets = (
        (
            "Kimlik",
            {
                "classes": ["tab"],
                "fields": (
                    "public_id",
                    "topic",
                    "subtopic",
                    "is_published",
                    "osym_sordu",
                    "difficulty",
                ),
            },
        ),
        (
            "Soru",
            {
                "classes": ["tab"],
                "fields": ("stem", "image", "figure_svg"),
            },
        ),
        (
            "Şıklar",
            {
                "classes": ["tab"],
                "fields": (
                    "option_a",
                    "option_b",
                    "option_c",
                    "option_d",
                    "option_e",
                    "correct_option",
                ),
            },
        ),
        (
            "Çözüm",
            {
                "classes": ["tab"],
                "fields": ("solution",),
            },
        ),
        (
            "Zorluk istatistikleri",
            {
                "classes": ["tab"],
                "fields": (
                    "attempt_count",
                    "correct_count",
                    "wrong_count",
                    "blank_count",
                ),
            },
        ),
        (
            "Zaman",
            {
                "classes": ["tab"],
                "fields": ("created_at", "updated_at"),
            },
        ),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(
            _rating_average=Avg("ratings__stars"),
            _rating_count=Count("ratings"),
        )

    @admin.display(ordering="_rating_average", description="Ortalama puan")
    def average_rating(self, obj: Question):
        if obj._rating_average is None:
            return "—"
        return f"{obj._rating_average:.2f} ★"

    @admin.display(ordering="_rating_count", description="Oy")
    def rating_count(self, obj: Question):
        return obj._rating_count


@admin.register(QuestionRating)
class QuestionRatingAdmin(ModelAdmin):
    list_display = ("question", "user", "stars", "created_at", "updated_at")
    list_select_related = ("question", "user")
    list_filter = ("stars", "question__topic__subject", "question__topic")
    search_fields = (
        "question__public_id",
        "question__stem",
        "user__email",
        "user__display_name",
    )
    readonly_fields = ("question", "user", "stars", "created_at", "updated_at")
    list_filter_sheet = False

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(QuestionAttempt)
class QuestionAttemptAdmin(ModelAdmin):
    list_display = ("question", "user", "outcome", "created_at")
    list_select_related = ("question", "user")
    list_filter = ("outcome", "question__topic__subject", "question__topic")
    search_fields = (
        "question__public_id",
        "user__email",
        "user__display_name",
    )
    readonly_fields = ("question", "user", "outcome", "created_at")
    list_filter_sheet = False

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(QuestionErrorReport)
class QuestionErrorReportAdmin(ModelAdmin):
    list_display = (
        "question",
        "category",
        "status",
        "user",
        "created_at",
        "updated_at",
    )
    list_select_related = ("question", "user", "question__topic")
    list_filter = ("status", "category", "question__topic__subject")
    search_fields = (
        "question__public_id",
        "question__stem",
        "user__email",
        "user__display_name",
        "note",
    )
    readonly_fields = ("question", "user", "created_at", "updated_at")
    list_filter_sheet = False

    def has_add_permission(self, request):
        return False


@admin.register(OcrIngestLog)
class OcrIngestLogAdmin(ModelAdmin):
    list_display = (
        "created_at",
        "status",
        "engine",
        "used_model",
        "ok",
        "issue_formula_missing",
        "issue_char_drift",
        "duplicate_match",
        "topic",
        "duplicate_question",
    )
    list_filter = (
        "status",
        "ok",
        "engine",
        "issue_formula_missing",
        "issue_char_drift",
        "duplicate_match",
        "topic__subject",
    )
    search_fields = (
        "image_path",
        "source_image_hash",
        "source_image_phash",
        "used_model",
        "raw_response",
        "stem",
        "raw_text",
        "error_message",
        "duplicate_question__public_id",
    )
    readonly_fields = (
        "created_at",
        "source_image_hash",
        "source_image_phash",
        "image_path",
        "engine",
        "used_model",
        "status",
        "topic",
        "duplicate_question",
        "duplicate_match",
        "initiated_by",
        "ok",
        "error_message",
        "raw_response",
        "stem",
        "options",
        "raw_text",
        "issue_formula_missing",
        "issue_char_drift",
    )
    list_filter_sheet = False

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

@admin.register(TopicLesson)
class TopicLessonAdmin(ModelAdmin):
    list_display = ("title", "topic", "sort_order", "is_published", "updated_at")
    list_filter = ("is_published", "topic__subject")
    search_fields = ("title", "public_id", "body")
    autocomplete_fields = ("topic",)
    list_filter_sheet = False


@admin.register(TopicSummaryCard)
class TopicSummaryCardAdmin(ModelAdmin):
    list_display = (
        "title",
        "kind",
        "topic",
        "sort_order",
        "is_published",
        "updated_at",
    )
    list_filter = ("kind", "is_published", "topic__subject")
    search_fields = ("title", "public_id", "body")
    autocomplete_fields = ("topic",)
    list_filter_sheet = False
    fields = (
        "public_id",
        "topic",
        "kind",
        "title",
        "body",
        "image",
        "sort_order",
        "is_published",
        "created_at",
        "updated_at",
    )
    readonly_fields = ("created_at", "updated_at")


@admin.register(TopicTest)
class TopicTestAdmin(ModelAdmin):
    list_display = (
        "title",
        "topic",
        "is_published",
        "question_count",
        "created_at",
    )
    list_filter = ("is_published", "topic__subject")
    search_fields = ("title", "public_id")
    autocomplete_fields = ("topic",)
    filter_horizontal = ("questions",)
    readonly_fields = ("created_at", "updated_at")
    list_filter_sheet = False
    compressed_fields = True
    warn_unsaved_form = True
    fieldsets = (
        (
            "Test",
            {
                "fields": (
                    "public_id",
                    "topic",
                    "title",
                    "description",
                    "time_limit_minutes",
                    "is_published",
                ),
            },
        ),
        (
            "Sorular",
            {
                "fields": ("questions",),
            },
        ),
        (
            "Zaman",
            {
                "fields": ("created_at", "updated_at"),
            },
        ),
    )


@admin.register(Announcement)
class AnnouncementAdmin(ModelAdmin):
    list_display = (
        "title",
        "is_published",
        "has_image",
        "push_sent_at",
        "push_success_count",
        "created_at",
    )
    list_filter = ("is_published",)
    search_fields = ("title", "body")
    readonly_fields = (
        "push_sent_at",
        "push_success_count",
        "push_fail_count",
        "created_at",
        "updated_at",
    )
    actions = ("send_push_notifications",)
    list_filter_sheet = False

    @admin.display(boolean=True, description="Fotoğraf")
    def has_image(self, obj: Announcement) -> bool:
        return bool(obj.image)

    @admin.action(description="Seçili duyuruları FCM ile gönder")
    def send_push_notifications(self, request, queryset):
        from django.contrib import messages as dj_messages

        from .push import send_announcement_push

        ok = fail = 0
        for item in queryset:
            result = send_announcement_push(item)
            if result.ok:
                ok += 1
            else:
                fail += 1
                dj_messages.error(request, f"{item.title}: {result.error}")
        if ok:
            dj_messages.success(request, f"{ok} duyuru bildirimi gönderildi.")
        if fail and not ok:
            dj_messages.warning(request, f"{fail} duyuru gönderilemedi.")


@admin.register(AppUser)
class AppUserAdmin(ModelAdmin):
    list_display = (
        "email",
        "display_name",
        "is_anonymous",
        "is_premium",
        "premium_granted_at",
        "premium_expires_at",
        "status_label",
        "last_login_at",
        "created_at",
    )
    list_filter = ("is_anonymous", "is_premium", "is_active")
    search_fields = ("email", "display_name", "google_sub")
    readonly_fields = (
        "google_sub",
        "api_token",
        "created_at",
        "updated_at",
        "last_login_at",
        "premium_granted_at",
        "is_anonymous",
    )
    fieldsets = (
        (
            None,
            {
                "fields": (
                    "email",
                    "display_name",
                    "photo_url",
                    "google_sub",
                    "is_anonymous",
                    "is_active",
                    "block_reason",
                ),
            },
        ),
        (
            "Premium",
            {
                "fields": (
                    "is_premium",
                    "premium_granted_at",
                    "premium_expires_at",
                    "premium_product_id",
                    "premium_grant_note",
                ),
            },
        ),
        (
            "Oturum",
            {
                "fields": (
                    "api_token",
                    "last_login_at",
                    "created_at",
                    "updated_at",
                ),
            },
        ),
    )
    list_filter_sheet = False
    compressed_fields = True
    actions = (
        "grant_free_premium",
        "revoke_free_premium",
        "send_direct_message",
        "block_selected_users",
        "unblock_selected_users",
    )

    @admin.action(description="Seçili kullanıcılara ücretsiz premium ver")
    def grant_free_premium(self, request, queryset):
        from django.utils.dateparse import parse_datetime

        if "apply" in request.POST:
            note = (request.POST.get("grant_note") or "").strip()
            expiry_raw = (request.POST.get("premium_expires_at") or "").strip()
            expires_at = parse_datetime(expiry_raw) if expiry_raw else None
            count = 0
            for user in queryset:
                user.grant_free_premium(expires_at=expires_at, note=note)
                count += 1
            self.message_user(
                request,
                f"{count} kullanıcıya ücretsiz premium tanımlandı.",
            )
            return None

        return render(
            request,
            "admin/content/appuser/grant_premium.html",
            {
                **self.admin_site.each_context(request),
                "users": queryset,
                "ids": list(queryset.values_list("pk", flat=True)),
                "action_checkbox_name": ACTION_CHECKBOX_NAME,
                "opts": self.model._meta,
                "title": "Ücretsiz premium ver",
            },
        )

    @admin.action(description="Seçili kullanıcıların ücretsiz premiumunu kaldır")
    def revoke_free_premium(self, request, queryset):
        count = 0
        for user in queryset.filter(is_premium=True):
            user.revoke_free_premium()
            count += 1
        self.message_user(request, f"{count} kullanıcının premiumu kaldırıldı.")

    @admin.display(description="Durum")
    def status_label(self, obj: AppUser) -> str:
        if obj.is_active:
            return "Aktif"
        reason = obj.block_reason.strip() if obj.block_reason else ""
        return f"Engelli{f' — {reason}' if reason else ''}"

    @admin.action(description="Seçili kullanıcılara mesaj gönder")
    def send_direct_message(self, request, queryset):
        from .push import send_user_message_push

        if "apply" in request.POST:
            title = (request.POST.get("title") or "").strip()
            body = (request.POST.get("body") or "").strip()
            send_push = request.POST.get("send_push") == "1"
            if not title or not body:
                self.message_user(
                    request, "Başlık ve mesaj zorunlu.", level=dj_messages.ERROR
                )
                return None

            ok = fail = 0
            for user in queryset:
                msg = UserMessage.objects.create(
                    user=user, title=title, body=body
                )
                if send_push:
                    result = send_user_message_push(msg)
                    if result.ok:
                        ok += 1
                    else:
                        fail += 1
                        self.message_user(
                            request,
                            f"{user.email}: {result.error}",
                            level=dj_messages.WARNING,
                        )
                else:
                    ok += 1

            self.message_user(
                request,
                f"Mesaj kaydedildi ({ok} kullanıcı"
                f"{', bildirim başarısız: ' + str(fail) if fail else ''}).",
            )
            return None

        return render(
            request,
            "admin/content/appuser/send_message.html",
            {
                **self.admin_site.each_context(request),
                "users": queryset,
                "ids": list(queryset.values_list("pk", flat=True)),
                "action_checkbox_name": ACTION_CHECKBOX_NAME,
                "opts": self.model._meta,
                "title": "Mesaj gönder",
            },
        )

    @admin.action(description="Seçili kullanıcıları engelle")
    def block_selected_users(self, request, queryset):
        reason = (request.POST.get("block_reason") or "").strip()
        count = 0
        for user in queryset.filter(is_active=True):
            user.block(reason=reason or "Admin tarafından engellendi")
            count += 1
        self.message_user(request, f"{count} kullanıcı engellendi.")

    @admin.action(description="Seçili kullanıcıların engelini kaldır")
    def unblock_selected_users(self, request, queryset):
        count = 0
        for user in queryset.filter(is_active=False):
            user.unblock()
            count += 1
        self.message_user(request, f"{count} kullanıcının engeli kaldırıldı.")


@admin.register(UserMessage)
class UserMessageAdmin(ModelAdmin):
    list_display = (
        "title",
        "user",
        "is_read",
        "push_sent_at",
        "push_success_count",
        "created_at",
    )
    list_filter = ("is_read",)
    search_fields = ("title", "body", "user__email", "user__display_name")
    autocomplete_fields = ("user",)
    readonly_fields = (
        "is_read",
        "push_sent_at",
        "push_success_count",
        "push_fail_count",
        "created_at",
    )
    list_filter_sheet = False
    actions = ("resend_push",)

    @admin.action(description="Bildirimi tekrar gönder")
    def resend_push(self, request, queryset):
        from .push import send_user_message_push

        ok = fail = 0
        for msg in queryset.select_related("user"):
            result = send_user_message_push(msg)
            if result.ok:
                ok += 1
            else:
                fail += 1
                self.message_user(
                    request,
                    f"{msg.user.email}: {result.error}",
                    level=dj_messages.WARNING,
                )
        if ok:
            self.message_user(request, f"{ok} mesaj bildirimi gönderildi.")


@admin.register(DeviceToken)
class DeviceTokenAdmin(ModelAdmin):
    list_display = (
        "platform",
        "user",
        "is_active",
        "app_version",
        "last_seen_at",
        "token_short",
    )
    list_filter = ("platform", "is_active")
    search_fields = ("token", "app_version", "user__email")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "last_seen_at")
    list_filter_sheet = False

    @admin.display(description="Jeton")
    def token_short(self, obj: DeviceToken) -> str:
        return f"{obj.token[:24]}…"


@admin.register(DailyMiniExam)
class DailyMiniExamAdmin(ModelAdmin):
    list_display = ("exam_date", "kpss_type", "question_count", "created_at")
    list_filter = ("kpss_type",)
    date_hierarchy = "exam_date"
    readonly_fields = ("created_at", "question_ids")

    @admin.display(description="Soru")
    def question_count(self, obj: DailyMiniExam) -> int:
        return len(obj.question_ids or [])


@admin.register(DailyMiniExamAttempt)
class DailyMiniExamAttemptAdmin(ModelAdmin):
    list_display = (
        "user",
        "exam_date",
        "kpss_type",
        "correct",
        "wrong",
        "blank",
        "duration_seconds",
        "completed_at",
    )
    list_filter = ("kpss_type", "exam_date")
    search_fields = ("user__email", "user__display_name")
    autocomplete_fields = ("user",)
    readonly_fields = (
        "correct",
        "wrong",
        "blank",
        "total",
        "duration_seconds",
        "wrong_question_ids",
        "answers",
        "completed_at",
    )
    date_hierarchy = "exam_date"


@admin.register(ExamType)
class ExamTypeAdmin(ModelAdmin):
    list_display = (
        "name",
        "slug",
        "exam_date",
        "yearly_repeat",
        "even_years_only",
        "content_type",
        "sort_order",
        "is_active",
    )
    list_editable = ("exam_date", "sort_order", "is_active")
    list_filter = ("is_active", "content_type", "yearly_repeat", "even_years_only")
    search_fields = ("name", "slug", "description")
    prepopulated_fields = {"slug": ("name",)}
    list_display_links = ("name",)
    list_filter_sheet = False

    def get_readonly_fields(self, request, obj=None):
        if obj:
            return ("slug",)
        return ()

    def get_prepopulated_fields(self, request, obj=None):
        if obj:
            return {}
        return self.prepopulated_fields


class ExamPackExamQuestionInline(TabularInline):
    model = ExamPackExamQuestion
    extra = 0
    autocomplete_fields = ("question",)
    ordering = ("sort_order",)


class ExamPackExamInline(TabularInline):
    model = ExamPackExam
    extra = 0
    show_change_link = True
    ordering = ("index",)


@admin.register(ExamDistributionTemplate)
class ExamDistributionTemplateAdmin(ModelAdmin):
    list_display = (
        "exam_type",
        "subject",
        "topic",
        "question_count",
        "updated_at",
    )
    list_filter = ("exam_type", "subject")
    search_fields = ("exam_type__name", "subject__name", "topic__name")
    autocomplete_fields = ("exam_type", "subject", "topic")


@admin.register(ExamPack)
class ExamPackAdmin(ModelAdmin):
    list_display = (
        "title",
        "public_id",
        "exam_type",
        "pack_kind",
        "subject",
        "exam_count",
        "is_published",
        "sort_order",
    )
    list_display_links = ("title", "public_id")
    list_editable = ("is_published", "sort_order")
    list_filter = ("pack_kind", "is_published", "exam_type")
    search_fields = ("title", "public_id", "play_product_id")
    inlines = (ExamPackExamInline,)
    autocomplete_fields = ("exam_type", "subject")
    actions = ("activate_packs", "deactivate_packs")

    @admin.action(description="Seçili paketleri aktif et (Dersler vitrini)")
    def activate_packs(self, request, queryset):
        updated = queryset.update(is_published=True)
        self.message_user(request, f"{updated} paket aktif edildi.")

    @admin.action(description="Seçili paketleri pasif et (vitrinden çıkar)")
    def deactivate_packs(self, request, queryset):
        updated = queryset.update(is_published=False)
        self.message_user(request, f"{updated} paket pasif edildi.")


@admin.register(ExamPackExam)
class ExamPackExamAdmin(ModelAdmin):
    list_display = ("pack", "index", "title", "question_count")
    list_filter = ("pack__exam_type",)
    search_fields = ("title", "pack__title")
    inlines = (ExamPackExamQuestionInline,)
    autocomplete_fields = ("pack",)


class PromoCodeRedemptionInline(TabularInline):
    model = PromoCodeRedemption
    extra = 0
    can_delete = False
    autocomplete_fields = ("user",)
    readonly_fields = ("user", "redeemed_at", "premium_expires_at")
    fields = ("user", "redeemed_at", "premium_expires_at")
    ordering = ("-redeemed_at",)

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(PromoCode)
class PromoCodeAdmin(ModelAdmin):
    list_display = (
        "code",
        "title",
        "max_redemptions",
        "usage_summary",
        "premium_duration_days",
        "valid_until",
        "is_active",
        "created_at",
    )
    list_filter = ("is_active",)
    search_fields = ("code", "title")
    readonly_fields = (
        "created_at",
        "updated_at",
        "usage_stats",
    )
    inlines = (PromoCodeRedemptionInline,)
    list_filter_sheet = False
    compressed_fields = True
    fieldsets = (
        (
            None,
            {
                "fields": (
                    "code",
                    "title",
                    "is_active",
                ),
            },
        ),
        (
            "Kota ve süre",
            {
                "fields": (
                    "max_redemptions",
                    "premium_duration_days",
                    "valid_from",
                    "valid_until",
                ),
            },
        ),
        (
            "İstatistik",
            {
                "fields": ("usage_stats",),
            },
        ),
        (
            "Kayıt",
            {
                "fields": ("created_at", "updated_at"),
            },
        ),
    )

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.annotate(_redemption_count=Count("redemptions"))

    @admin.display(description="Kullanım")
    def usage_summary(self, obj: PromoCode) -> str:
        used = getattr(obj, "_redemption_count", obj.redemption_count)
        remaining = max(0, obj.max_redemptions - used)
        return f"{used}/{obj.max_redemptions} · kalan {remaining}"

    @admin.display(description="Kullanım özeti")
    def usage_stats(self, obj: PromoCode) -> str:
        if obj.pk is None:
            return "Kayıt oluşturulduktan sonra görünür."
        used = obj.redemption_count
        remaining = obj.remaining_slots
        return (
            f"Toplam kullanım: {used} · Kalan kota: {remaining} · "
            f"Premium süresi: {obj.premium_duration_days} gün"
        )


@admin.register(PromoCodeRedemption)
class PromoCodeRedemptionAdmin(ModelAdmin):
    list_display = (
        "promo_code",
        "user",
        "redeemed_at",
        "premium_expires_at",
    )
    list_filter = ("promo_code", "redeemed_at")
    search_fields = (
        "promo_code__code",
        "user__email",
        "user__display_name",
    )
    autocomplete_fields = ("promo_code", "user")
    readonly_fields = ("redeemed_at",)
    date_hierarchy = "redeemed_at"
    list_filter_sheet = False
