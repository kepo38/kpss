"""Premium rehberli içerik paneli — Ders → Konu → Bilgi/Soru/Test."""

from __future__ import annotations

import math
import types
import uuid

from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.core.exceptions import ValidationError
from django.core.files.base import ContentFile
from django.core.paginator import Paginator
from django.db import transaction
from django.db.models import Avg, Count, Sum
from django.http import HttpRequest, HttpResponse, HttpResponseBadRequest, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render, reverse
from django.templatetags.static import static
from django.utils.text import slugify
from django.views.decorators.http import require_http_methods, require_POST

from .models import (
    Announcement,
    AppUser,
    ERROR_REPORT_CATEGORY_CHOICES,
    ERROR_REPORT_STATUS_CHOICES,
    ExamType,
    MapTemplate,
    Question,
    QuestionErrorReport,
    QuestionScenario,
    Subject,
    Topic,
    TopicLesson,
    TopicTest,
)
from .map_catalog import MAP_CATALOG, iter_map_entries, map_template_choices
from .map_question_renderer import render_map_question, validate_map_markers
from .ocr import ocr_question_image, strip_option_emphasis
from .svg_sanitize import extract_svg, is_safe_svg
from .push import firebase_ready, send_announcement_push
from .question_fingerprint import (
    content_fingerprint,
    duplicate_payload,
    find_duplicate_question,
    image_fingerprint,
    stem_fingerprint,
)
from .embeddings import refresh_question_embedding
from .test_grouping import (
    assign_question_to_test,
    rebalance_topic_tests,
    tests_for_dropdown,
)

staff_required = user_passes_test(lambda u: u.is_active and u.is_staff)


def _pid(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:10]}"


def _store_ocr_draft(
    request: HttpRequest,
    *,
    topic_id: int,
    stem: str,
    options: dict[str, str],
    figure_svg: str = "",
    solution: str = "",
    correct_option: str = "A",
    source_image_hash: str = "",
    test_assignment: str = "auto",
) -> None:
    request.session["ocr_draft"] = {
        "topic_id": topic_id,
        "stem": stem,
        "option_a": options.get("A", ""),
        "option_b": options.get("B", ""),
        "option_c": options.get("C", ""),
        "option_d": options.get("D", ""),
        "option_e": options.get("E", ""),
        "figure_svg": figure_svg,
        "solution": solution,
        "correct_option": correct_option,
        "source_image_hash": source_image_hash,
        "test_assignment": test_assignment,
    }
    request.session.modified = True


def _pop_ocr_draft(request: HttpRequest, topic_id: int) -> dict | None:
    draft = request.session.pop("ocr_draft", None)
    if isinstance(draft, dict) and draft.get("topic_id") == topic_id:
        return draft
    return None


def _store_manual_prefs(
    request: HttpRequest,
    *,
    topic_id: int,
    test_assignment: str = "auto",
) -> None:
    request.session["manual_question_prefs"] = {
        "topic_id": topic_id,
        "test_assignment": test_assignment,
    }
    request.session.modified = True


def _pop_manual_prefs(request: HttpRequest, topic_id: int) -> dict | None:
    prefs = request.session.pop("manual_question_prefs", None)
    if isinstance(prefs, dict) and prefs.get("topic_id") == topic_id:
        return prefs
    return None


def _question_picker_state(request: HttpRequest) -> dict:
    """Ders/konu seçimi — hızlı OCR ve manuel soru formları."""
    subjects = Subject.objects.filter(is_active=True).order_by(
        "sort_order", "name"
    )
    selected_subject_id = request.POST.get("subject_id") or request.GET.get(
        "subject_id"
    )
    selected_topic_id = request.POST.get("topic_id") or request.GET.get(
        "topic_id"
    )
    if selected_topic_id and str(selected_topic_id).isdigit():
        topic = (
            Topic.objects.filter(pk=int(selected_topic_id), is_active=True)
            .select_related("subject")
            .first()
        )
        if topic:
            selected_subject_id = str(topic.subject_id)
    topics = Topic.objects.none()
    if selected_subject_id and str(selected_subject_id).isdigit():
        topics = Topic.objects.filter(
            subject_id=int(selected_subject_id), is_active=True
        ).order_by("sort_order", "name")
    test_dd = None
    if selected_topic_id and str(selected_topic_id).isdigit():
        t = Topic.objects.filter(pk=int(selected_topic_id)).first()
        if t:
            test_dd = tests_for_dropdown(t)
    return {
        "subjects": subjects,
        "topics": topics,
        "selected_subject_id": int(selected_subject_id)
        if selected_subject_id and str(selected_subject_id).isdigit()
        else None,
        "selected_topic_id": int(selected_topic_id)
        if selected_topic_id and str(selected_topic_id).isdigit()
        else None,
        "selected_assignment": request.POST.get("test_assignment", "auto"),
        "test_dd": test_dd,
    }


def _question_from_draft(draft: dict) -> types.SimpleNamespace:
    return types.SimpleNamespace(
        pk=None,
        stem=draft.get("stem", ""),
        subtopic="",
        option_a=draft.get("option_a", ""),
        option_b=draft.get("option_b", ""),
        option_c=draft.get("option_c", ""),
        option_d=draft.get("option_d", ""),
        option_e=draft.get("option_e", ""),
        correct_option=draft.get("correct_option", "A") or "A",
        solution=draft.get("solution", ""),
        figure_svg=draft.get("figure_svg", ""),
        source_image_hash=draft.get("source_image_hash", ""),
        is_published=True,
        osym_sordu=False,
        map_template="",
        map_markers=[],
        image=None,
    )


def _discard_question_image(question: Question) -> None:
    """Soru görselini diskten sil — OCR sonrası yer kaplamasın."""
    if question.image:
        question.image.delete(save=False)
        question.image = None


def _sanitize_figure_svg(raw: str) -> str:
    code = extract_svg(raw or "")
    return code if is_safe_svg(code) else ""


@login_required
@staff_required
def panel_home(request: HttpRequest) -> HttpResponse:
    subjects = (
        Subject.objects.annotate(
            topic_count=Count("topics", distinct=True),
            question_count=Count("topics__questions", distinct=True),
        )
        .order_by("sort_order", "name")
    )
    return render(
        request,
        "panel/subjects.html",
        {
            "subjects": subjects,
            "page_title": "Dersler",
        },
    )


def _map_templates_for_editor() -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    for map_id, entry in iter_map_entries():
        if entry.get("source") == "media":
            item = {
                "kind": entry["kind"],
                "title": entry["title"],
                "asset": entry.get("url") or "",
            }
            editor_url = entry.get("editor_url") or entry.get("url") or ""
            if editor_url:
                item["editor_asset"] = editor_url
        else:
            item = {
                "kind": entry["kind"],
                "title": entry["title"],
                "asset": static(entry["asset"]),
            }
            editor_asset = entry.get("editor_asset")
            if editor_asset:
                item["editor_asset"] = static(editor_asset)
        result[map_id] = item
    return result


def _maps_list_context() -> list[dict]:
    maps: list[dict] = []
    for map_id, entry in iter_map_entries():
        builtin = bool(entry.get("builtin"))
        if entry.get("source") == "media":
            preview = entry.get("url") or ""
            preview_is_static = False
        else:
            preview = entry["asset"]
            preview_is_static = True
        maps.append(
            {
                "id": map_id,
                "title": entry["title"],
                "kind": entry["kind"],
                "description": entry.get("description", ""),
                "preview": preview,
                "preview_is_static": preview_is_static,
                "can_delete": not builtin,
                "builtin": builtin,
            }
        )
    return maps


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_maps(request: HttpRequest) -> HttpResponse:
    """Harita şablonlarını listele; POST ile yeni harita ekle."""
    if request.method == "POST":
        title = (request.POST.get("title") or "").strip()
        kind = (request.POST.get("kind") or MapTemplate.KIND_STATIC).strip()
        description = (request.POST.get("description") or "").strip()
        image = request.FILES.get("image")
        editor_image = request.FILES.get("editor_image")

        if kind not in {MapTemplate.KIND_MARKER, MapTemplate.KIND_STATIC}:
            messages.error(request, "Geçersiz harita türü.")
            return redirect("panel_maps")
        if not title:
            messages.error(request, "Başlık gerekli.")
            return redirect("panel_maps")
        if not image:
            messages.error(request, "Harita görseli gerekli.")
            return redirect("panel_maps")

        slug = slugify(title)
        if not slug:
            slug = f"harita-{uuid.uuid4().hex[:8]}"
        if slug in MAP_CATALOG or MapTemplate.objects.filter(slug=slug).exists():
            messages.error(request, f"“{slug}” kodu zaten kullanılıyor. Başlığı değiştirin.")
            return redirect("panel_maps")
        MapTemplate.objects.create(
            slug=slug,
            title=title,
            kind=kind,
            description=description[:255],
            image=image,
            editor_image=editor_image if editor_image else None,
        )
        messages.success(request, f"“{title}” haritası eklendi.")
        return redirect("panel_maps")

    return render(
        request,
        "panel/maps.html",
        {
            "maps": _maps_list_context(),
            "page_title": "Haritalar",
            "kind_choices": MapTemplate.KIND_CHOICES,
        },
    )


@login_required
@staff_required
@require_POST
def panel_map_delete(request: HttpRequest, slug: str) -> HttpResponse:
    """Özel harita şablonunu sil (sistem haritaları silinmez)."""
    if slug in MAP_CATALOG:
        messages.error(request, "Sistem haritaları silinemez.")
        return redirect("panel_maps")

    tmpl = get_object_or_404(MapTemplate, slug=slug)
    in_use = Question.objects.filter(map_template=slug).count()
    if in_use:
        messages.error(
            request,
            f"“{tmpl.title}” {in_use} soruda kullanılıyor; önce sorulardan kaldırın.",
        )
        return redirect("panel_maps")

    title = tmpl.title
    tmpl.image.delete(save=False)
    if tmpl.editor_image:
        tmpl.editor_image.delete(save=False)
    tmpl.delete()
    messages.success(request, f"“{title}” silindi.")
    return redirect("panel_maps")


def _quality_number(
    raw: str | None,
    *,
    default: float,
    minimum: float,
    maximum: float,
) -> float:
    try:
        value = float(raw) if raw not in (None, "") else default
    except (TypeError, ValueError):
        return default
    if not math.isfinite(value):
        return default
    return min(max(value, minimum), maximum)


def _quality_id(raw: str | None) -> int | None:
    value = (raw or "").strip()
    if not value.isdigit():
        return None
    parsed = int(value)
    return parsed if parsed <= 9_223_372_036_854_775_807 else None


@login_required
@staff_required
def panel_quality(request: HttpRequest) -> HttpResponse:
    """Ders/konu bazında düşük puanlı soruları inceleme ekranı."""

    min_votes = int(
        _quality_number(
            request.GET.get("min_votes"),
            default=10,
            minimum=1,
            maximum=10000,
        )
    )
    max_rating = _quality_number(
        request.GET.get("max_rating"),
        default=2.5,
        minimum=1,
        maximum=5,
    )
    subject_raw = request.GET.get("subject", "")
    topic_raw = request.GET.get("topic", "")
    subject_id = _quality_id(subject_raw)
    topic_id = _quality_id(topic_raw)

    annotated_questions = Question.objects.filter(
        is_published=True,
    ).select_related(
        "topic",
        "topic__subject",
    ).annotate(
        rating_average=Avg("ratings__stars"),
        rating_count=Count("ratings"),
        rating_sum=Sum("ratings__stars"),
    )

    summary_subjects = Subject.objects.order_by("sort_order", "name")
    summary_questions = Question.objects.filter(
        is_published=True,
    ).values(
        "id",
        "topic__subject_id",
    ).annotate(
        rating_count=Count("ratings"),
        rating_sum=Sum("ratings__stars"),
    )
    if subject_id is not None:
        summary_subjects = summary_subjects.filter(pk=subject_id)
        summary_questions = summary_questions.filter(topic__subject_id=subject_id)
    if topic_id is not None:
        summary_subjects = summary_subjects.filter(topics__id=topic_id).distinct()
        summary_questions = summary_questions.filter(topic_id=topic_id)

    summary_rows: dict[int, dict] = {}
    for subject in summary_subjects:
        summary_rows[subject.id] = {
            "subject": subject,
            "rating_sum": 0,
            "total_votes": 0,
            "eligible_questions": 0,
            "low_questions": 0,
        }
    for question in summary_questions:
        row = summary_rows.get(question["topic__subject_id"])
        if row is None:
            continue
        count = int(question["rating_count"] or 0)
        rating_sum = int(question["rating_sum"] or 0)
        row["rating_sum"] += rating_sum
        row["total_votes"] += count
        if count >= min_votes:
            row["eligible_questions"] += 1
            if count and rating_sum / count <= max_rating:
                row["low_questions"] += 1

    subject_summaries = []
    for row in summary_rows.values():
        votes = row["total_votes"]
        row["average_rating"] = (
            row["rating_sum"] / votes if votes else None
        )
        subject_summaries.append(row)
    subject_summaries.sort(
        key=lambda row: (
            row["average_rating"] is None,
            row["average_rating"] or 0,
            row["subject"].sort_order,
        )
    )

    low_questions = annotated_questions.filter(
        rating_count__gte=min_votes,
        rating_average__lte=max_rating,
    )
    if subject_id is not None:
        low_questions = low_questions.filter(topic__subject_id=subject_id)
    if topic_id is not None:
        low_questions = low_questions.filter(topic_id=topic_id)
    low_questions = low_questions.order_by(
        "rating_average",
        "-rating_count",
        "public_id",
    )
    paginator = Paginator(low_questions, 50)
    page_obj = paginator.get_page(request.GET.get("page"))
    page_query = request.GET.copy()
    page_query.pop("page", None)

    topics = Topic.objects.select_related("subject").order_by(
        "subject__sort_order",
        "sort_order",
        "name",
    )
    if subject_id is not None:
        topics = topics.filter(subject_id=subject_id)

    return render(
        request,
        "panel/quality_dashboard.html",
        {
            "page_title": "Soru kalitesi",
            "subjects": Subject.objects.order_by("sort_order", "name"),
            "topics": topics,
            "subject_summaries": subject_summaries,
            "low_questions": page_obj,
            "low_question_count": paginator.count,
            "page_query": page_query.urlencode(),
            "selected_subject_id": subject_id,
            "selected_topic_id": topic_id,
            "min_votes": min_votes,
            "max_rating": max_rating,
        },
    )


@login_required
@staff_required
def panel_error_reports(request: HttpRequest) -> HttpResponse:
    """Öğrenci hata bildirimleri — incelenecek sorular havuzu."""
    status = (request.GET.get("status") or "open").strip()
    category = (request.GET.get("category") or "").strip()
    subject_id = _quality_id(request.GET.get("subject"))
    topic_id = _quality_id(request.GET.get("topic"))

    qs = QuestionErrorReport.objects.select_related(
        "question",
        "question__topic",
        "question__topic__subject",
        "user",
    )
    if status and status != "all":
        qs = qs.filter(status=status)
    if category:
        qs = qs.filter(category=category)
    if subject_id is not None:
        qs = qs.filter(question__topic__subject_id=subject_id)
    if topic_id is not None:
        qs = qs.filter(question__topic_id=topic_id)

    qs = qs.order_by("-created_at")
    paginator = Paginator(qs, 40)
    page_obj = paginator.get_page(request.GET.get("page"))
    page_query = request.GET.copy()
    page_query.pop("page", None)

    topics = Topic.objects.select_related("subject").order_by(
        "subject__sort_order",
        "sort_order",
        "name",
    )
    if subject_id is not None:
        topics = topics.filter(subject_id=subject_id)

    status_counts = {
        row["status"]: row["count"]
        for row in QuestionErrorReport.objects.values("status").annotate(
            count=Count("id")
        )
    }

    return render(
        request,
        "panel/error_reports.html",
        {
            "page_title": "İncelenecek sorular",
            "reports": page_obj,
            "report_count": paginator.count,
            "page_query": page_query.urlencode(),
            "subjects": Subject.objects.order_by("sort_order", "name"),
            "topics": topics,
            "selected_subject_id": subject_id,
            "selected_topic_id": topic_id,
            "selected_status": status,
            "selected_category": category,
            "status_choices": ERROR_REPORT_STATUS_CHOICES,
            "category_choices": ERROR_REPORT_CATEGORY_CHOICES,
            "status_counts": status_counts,
            "open_count": status_counts.get("open", 0),
        },
    )


@login_required
@staff_required
@require_POST
def panel_error_report_status(
    request: HttpRequest, report_id: int
) -> HttpResponse:
    report = get_object_or_404(QuestionErrorReport, pk=report_id)
    new_status = (request.POST.get("status") or "").strip()
    valid = {c[0] for c in ERROR_REPORT_STATUS_CHOICES}
    if new_status not in valid:
        return HttpResponseBadRequest("Geçersiz durum.")
    report.status = new_status
    report.save(update_fields=["status", "updated_at"])
    messages.success(
        request,
        f"{report.question.public_id} bildirimi → "
        f"{report.get_status_display()}.",
    )
    next_url = request.POST.get("next") or reverse("panel_error_reports")
    return redirect(next_url)


@login_required
@staff_required
def panel_topic_options(request: HttpRequest, subject_id: int) -> HttpResponse:
    """HTMX: derse göre konu <option> listesi."""
    subject = get_object_or_404(Subject, pk=subject_id)
    topics = subject.topics.filter(is_active=True).order_by(
        "sort_order", "name"
    )
    selected_raw = request.GET.get("selected") or ""
    selected_topic_id = (
        int(selected_raw) if selected_raw.isdigit() else None
    )
    return render(
        request,
        "panel/partials/topic_options.html",
        {
            "topics": topics,
            "selected_topic_id": selected_topic_id,
        },
    )


@login_required
@staff_required
def panel_test_options(request: HttpRequest, topic_id: int) -> HttpResponse:
    """Konuya göre test atama <option> listesi."""
    topic = get_object_or_404(Topic, pk=topic_id)
    selected = request.GET.get("selected")
    selected_id = int(selected) if selected and selected.isdigit() else None
    ctx = tests_for_dropdown(topic, selected_test_id=selected_id)
    return render(request, "panel/partials/test_options.html", ctx)


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_quick_question(request: HttpRequest) -> HttpResponse:
    """Görsel yükle → ders/konu seç → onayla → soru taslağı oluştur."""
    picker = _question_picker_state(request)
    subjects = picker["subjects"]
    topics = picker["topics"]
    selected_subject_id = picker["selected_subject_id"]
    selected_topic_id = picker["selected_topic_id"]
    test_dd = picker["test_dd"]

    error = ""
    duplicate = None
    force_duplicate = request.POST.get("force_duplicate") == "1"
    if request.method == "POST":
        topic_id = request.POST.get("topic_id")
        image = request.FILES.get("image")
        if not image:
            error = "Soru görseli zorunlu."
            messages.error(
                request,
                "Soru görseli yüklenmedi. Lütfen bir görsel seçip tekrar deneyin.",
            )
        elif not topic_id:
            error = "Ders ve konu seçmelisiniz."
            messages.error(request, "Ders ve konu seçmeden OCR yapılamaz.")
        else:
            topic = get_object_or_404(Topic, pk=topic_id, is_active=True)
            try:
                img_hash = image_fingerprint(image)
                if hasattr(image, "seek"):
                    image.seek(0)
                ocr = ocr_question_image(image)
            except Exception:  # noqa: BLE001
                messages.error(
                    request,
                    "OCR sırasında beklenmeyen bir hata oluştu. "
                    "Görseli kontrol edip tekrar deneyin.",
                )
                error = "OCR başarısız."
            else:
                if hasattr(image, "seek"):
                    image.seek(0)

                hard_fail = (not ocr.ok) and not (
                    (ocr.stem or "").strip() or (ocr.raw_text or "").strip()
                )
                if hard_fail:
                    messages.error(
                        request,
                        ocr.error
                        or "Görselden metin okunamadı. "
                        "Tesseract kurulumunu veya görsel kalitesini kontrol edin.",
                    )
                    error = ocr.error or "Görselden metin okunamadı."
                else:
                    stem = (ocr.stem or "").strip()
                    if not stem:
                        stem = "Aşağıdaki görsele göre cevaplayınız."

                    opts = ocr.options
                    option_a = strip_option_emphasis(
                        (opts.get("A") or "").strip()
                    )
                    option_b = strip_option_emphasis(
                        (opts.get("B") or "").strip()
                    )
                    option_c = strip_option_emphasis(
                        (opts.get("C") or "").strip()
                    )
                    option_d = strip_option_emphasis(
                        (opts.get("D") or "").strip()
                    )
                    option_e = strip_option_emphasis(
                        (opts.get("E") or "").strip()
                    )
                    figure_svg = _sanitize_figure_svg(
                        getattr(ocr, "figure_svg", "") or ""
                    )
                    correct_option = (
                        getattr(ocr, "correct_option", "") or "A"
                    )
                    if correct_option not in "ABCDE":
                        correct_option = "A"
                    solution = (getattr(ocr, "solution", "") or "").strip()

                    c_hash = content_fingerprint(
                        stem,
                        option_a,
                        option_b,
                        option_c,
                        option_d,
                        option_e,
                    )
                    s_hash = stem_fingerprint(stem)
                    dup, match = find_duplicate_question(
                        content_hash=c_hash,
                        stem_hash=s_hash,
                        image_hash=img_hash,
                        require_options=bool(
                            option_a and option_b and option_c
                        ),
                    )
                    if dup and not force_duplicate:
                        duplicate = duplicate_payload(dup, match)
                        error = (
                            "Bu soruyu daha önce yüklediniz. "
                            "Tüm sorular benzersiz olmalı. "
                            f"Mevcut kayıt: {duplicate['subject_name']} · "
                            f"{duplicate['topic_name']} · "
                            f"{duplicate['public_id']}"
                        )
                        messages.error(request, error)
                    else:
                        _store_ocr_draft(
                            request,
                            topic_id=topic.id,
                            stem=stem,
                            options={
                                "A": option_a,
                                "B": option_b,
                                "C": option_c,
                                "D": option_d,
                                "E": option_e,
                            },
                            figure_svg=figure_svg,
                            solution=solution,
                            correct_option=correct_option,
                            source_image_hash=img_hash,
                            test_assignment=request.POST.get(
                                "test_assignment", "auto"
                            ),
                        )
                        if ocr.ok and any(opts.values()):
                            messages.success(
                                request,
                                "Görselden metin okundu — "
                                "kontrol edip Kaydet'e basın.",
                            )
                        elif ocr.raw_text:
                            messages.warning(
                                request,
                                "Kısmi okuma — alanları düzenleyip "
                                "Kaydet'e basın.",
                            )
                        else:
                            messages.warning(
                                request,
                                "Metin okunamadı — alanları elle doldurup "
                                "Kaydet'e basın.",
                            )
                        return redirect(
                            "panel_question_new", topic_id=topic.id
                        )

    return render(
        request,
        "panel/quick_question.html",
        {
            **picker,
            "error": error,
            "duplicate": duplicate,
            "page_title": "Görselden soru ekle",
        },
    )


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_manual_question(request: HttpRequest) -> HttpResponse:
    """Ders/konu seç → metin ve şıkları elle gir."""
    picker = _question_picker_state(request)
    error = ""

    if request.method == "POST":
        topic_id = request.POST.get("topic_id")
        if not topic_id:
            error = "Ders ve konu seçmelisiniz."
        else:
            topic = get_object_or_404(Topic, pk=topic_id, is_active=True)
            _store_manual_prefs(
                request,
                topic_id=topic.id,
                test_assignment=request.POST.get("test_assignment", "auto"),
            )
            return redirect("panel_question_new", topic_id=topic.id)

    return render(
        request,
        "panel/manual_question.html",
        {
            **picker,
            "error": error,
            "page_title": "Manuel soru ekle",
        },
    )


@login_required
@staff_required
@require_POST
def panel_ocr_question(request: HttpRequest) -> HttpResponse:
    """Görsel yükle → JSON stem + A–E (doğru cevap yok)."""
    image = request.FILES.get("image")
    if not image:
        messages.error(
            request,
            "Soru görseli yüklenmedi. Lütfen bir görsel seçip tekrar deneyin.",
        )
        return JsonResponse(
            {"ok": False, "error": "Görsel gerekli."},
            status=400,
        )

    exclude_raw = request.POST.get("exclude_question_id") or ""
    exclude_pk = int(exclude_raw) if exclude_raw.isdigit() else None

    try:
        img_hash = image_fingerprint(image)
        if hasattr(image, "seek"):
            image.seek(0)
        result = ocr_question_image(image)
    except Exception:  # noqa: BLE001
        messages.error(
            request,
            "OCR sırasında beklenmeyen bir hata oluştu. "
            "Görseli kontrol edip tekrar deneyin.",
        )
        return JsonResponse(
            {
                "ok": False,
                "error": "OCR başarısız.",
                "stem": "",
                "options": {k: "" for k in "ABCDE"},
            },
            status=500,
        )

    hard_fail = (not result.ok) and not (
        (result.stem or "").strip() or (result.raw_text or "").strip()
    )
    if hard_fail:
        err = result.error or "Görselden metin okunamadı."
        messages.error(request, err)
        return JsonResponse(
            {
                "ok": False,
                "error": err,
                "stem": "",
                "options": result.options or {k: "" for k in "ABCDE"},
                "raw_text": result.raw_text or "",
                "engine": getattr(result, "engine", "tesseract"),
            },
            status=422,
            json_dumps_params={"ensure_ascii": False},
            charset="utf-8",
        )

    opts = result.options or {}
    c_hash = content_fingerprint(
        result.stem or "",
        opts.get("A", ""),
        opts.get("B", ""),
        opts.get("C", ""),
        opts.get("D", ""),
        opts.get("E", ""),
    )
    s_hash = stem_fingerprint(result.stem or "")
    dup, match = find_duplicate_question(
        content_hash=c_hash,
        stem_hash=s_hash,
        image_hash=img_hash,
        exclude_pk=exclude_pk,
        require_options=bool(
            (opts.get("A") or "").strip()
            and (opts.get("B") or "").strip()
            and (opts.get("C") or "").strip()
        ),
    )
    payload = {
        "ok": result.ok,
        "stem": result.stem,
        "options": result.options,
        "soru_metni": result.stem,
        "siklar": result.options,
        "sekil_kodu": getattr(result, "figure_svg", "") or "",
        "figure_svg": getattr(result, "figure_svg", "") or "",
        "dogru_cevap": getattr(result, "correct_option", "") or "",
        "correct_option": getattr(result, "correct_option", "") or "",
        "detayli_cozum": getattr(result, "solution", "") or "",
        "solution": getattr(result, "solution", "") or "",
        "raw_text": result.raw_text,
        "error": result.error,
        "engine": getattr(result, "engine", "tesseract"),
        "image_hash": img_hash,
        "content_hash": c_hash,
        "duplicate": duplicate_payload(dup, match) if dup else None,
    }
    return JsonResponse(
        payload,
        json_dumps_params={"ensure_ascii": False},
        charset="utf-8",
    )


@login_required
@staff_required
def panel_subject(request: HttpRequest, subject_id: int) -> HttpResponse:
    subject = get_object_or_404(Subject, pk=subject_id)
    topics = subject.topics.order_by("sort_order", "name", "id")
    question_count = Question.objects.filter(topic__subject=subject).count()
    return render(
        request,
        "panel/topics.html",
        {
            "subject": subject,
            "topics": topics,
            "question_count": question_count,
            "page_title": subject.name,
        },
    )


def _unique_topic_slug(
    subject: Subject, base: str, *, exclude_pk: int | None = None
) -> str:
    slug = (base or "konu").strip().lower()[:64]
    if not slug:
        slug = "konu"
    candidate = slug
    n = 2
    while True:
        qs = Topic.objects.filter(subject=subject, slug=candidate)
        if exclude_pk is not None:
            qs = qs.exclude(pk=exclude_pk)
        if not qs.exists():
            return candidate
        candidate = f"{slug}_{n}"[:64]
        n += 1


def _parse_subtopics(raw: str) -> list[str]:
    items: list[str] = []
    for line in (raw or "").replace("\r\n", "\n").split("\n"):
        for part in line.split(","):
            s = part.strip()
            if s and s not in items:
                items.append(s)
    return items


def _topic_from_post(
    request: HttpRequest, subject: Subject, topic: Topic | None
) -> Topic:
    name = (request.POST.get("name") or "").strip()
    slug_raw = (request.POST.get("slug") or "").strip()
    subtopics = _parse_subtopics(request.POST.get("subtopics", ""))
    is_active = request.POST.get("is_active") == "on"

    obj = topic or Topic(subject=subject)
    obj.name = name
    base_slug = slugify(slug_raw, allow_unicode=False) if slug_raw else slugify(
        name, allow_unicode=False
    )
    if not base_slug:
        base_slug = f"{subject.slug}_konu"
    if topic and not slug_raw:
        obj.slug = topic.slug
    elif not slug_raw and not topic:
        prefixed = f"{subject.slug}_{base_slug}"[:64]
        obj.slug = _unique_topic_slug(subject, prefixed)
    else:
        obj.slug = _unique_topic_slug(
            subject, base_slug, exclude_pk=obj.pk if obj.pk else None
        )
    obj.subtopics = subtopics
    # Kapasite konu workspace'te ayarlanır; yeni konuda model default (20) kalır.
    if "questions_per_test" in request.POST:
        try:
            questions_per_test = int(request.POST.get("questions_per_test") or 20)
        except ValueError:
            questions_per_test = 20
        obj.questions_per_test = max(1, min(200, questions_per_test))
    obj.is_active = is_active
    if not topic:
        last = subject.topics.order_by("-sort_order").values_list(
            "sort_order", flat=True
        ).first()
        obj.sort_order = (last or 0) + 1
    return obj


def _renumber_topic_sort_orders(subject: Subject) -> None:
    """Keep remaining topics on contiguous 1..N sort orders."""
    topics = list(subject.topics.order_by("sort_order", "name", "id"))
    with transaction.atomic():
        for sort_order, topic in enumerate(topics, start=1):
            if topic.sort_order != sort_order:
                topic.sort_order = sort_order
                topic.save(update_fields=["sort_order"])


def _reorder_topics(subject: Subject, topic_ids: list[str]) -> bool:
    """Persist a complete drag-and-drop topic order as contiguous values."""
    topics = list(subject.topics.order_by("sort_order", "name", "id"))
    expected_ids = {str(topic.id) for topic in topics}
    if len(topic_ids) != len(topics) or set(topic_ids) != expected_ids:
        return False

    by_id = {str(topic.id): topic for topic in topics}
    with transaction.atomic():
        for sort_order, topic_id in enumerate(topic_ids, start=1):
            topic = by_id[topic_id]
            if topic.sort_order != sort_order:
                topic.sort_order = sort_order
                topic.save(update_fields=["sort_order"])
    return True


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_topic_edit(
    request: HttpRequest, subject_id: int, topic_id: int | None = None
) -> HttpResponse:
    subject = get_object_or_404(Subject, pk=subject_id)
    topic = (
        get_object_or_404(Topic, pk=topic_id, subject=subject)
        if topic_id
        else None
    )
    if request.method == "POST":
        draft = _topic_from_post(request, subject, topic)
        if not draft.name:
            messages.error(request, "Konu adı gerekli.")
            topic = draft
        else:
            draft.save()
            messages.success(request, f"“{draft.name}” kaydedildi.")
            return redirect("panel_subject", subject_id=subject.id)
    return render(
        request,
        "panel/topic_form.html",
        {
            "subject": subject,
            "topic": topic,
            "page_title": "Konu düzenle" if topic else "Yeni konu",
        },
    )


@login_required
@staff_required
@require_POST
def panel_topic_reorder(request: HttpRequest, subject_id: int) -> HttpResponse:
    subject = get_object_or_404(Subject, pk=subject_id)
    topic_ids = request.POST.getlist("topic_ids")
    if _reorder_topics(subject, topic_ids):
        messages.success(request, "Konu sırası güncellendi.")
        return HttpResponse(status=204)
    return HttpResponseBadRequest("Geçersiz konu sırası.")


@login_required
@staff_required
@require_POST
def panel_topic_delete(
    request: HttpRequest, subject_id: int, topic_id: int
) -> HttpResponse:
    """Konuyu ve bağlı soru/bilgi/test/grupları sil."""
    subject = get_object_or_404(Subject, pk=subject_id)
    topic = get_object_or_404(Topic, pk=topic_id, subject=subject)
    name = topic.name
    q_count = topic.questions.count()
    topic.delete()
    _renumber_topic_sort_orders(subject)
    messages.success(
        request,
        f"“{name}” silindi"
        + (f" ({q_count} soru dahil)." if q_count else "."),
    )
    return redirect("panel_subject", subject_id=subject.id)


@login_required
@staff_required
@require_POST
def panel_topic_toggle(request: HttpRequest, topic_id: int) -> HttpResponse:
    topic = get_object_or_404(Topic, pk=topic_id)
    topic.is_active = not topic.is_active
    topic.save(update_fields=["is_active"])
    return render(
        request,
        "panel/partials/topic_row.html",
        {"topic": topic, "subject": topic.subject},
    )


@login_required
@staff_required
@require_POST
def panel_topic_capacity(request: HttpRequest, topic_id: int) -> HttpResponse:
    """Test başına soru sayısını güncelle ve testleri yeniden dengele."""
    topic = get_object_or_404(Topic, pk=topic_id)
    raw = request.POST.get("questions_per_test", "").strip()
    try:
        capacity = int(raw)
    except ValueError:
        messages.error(request, "Geçerli bir sayı girin.")
        return redirect("panel_topic", topic_id=topic.id, tab="tests")

    if capacity < 1 or capacity > 200:
        messages.error(request, "Soru sayısı 1–200 arasında olmalı.")
        return redirect("panel_topic", topic_id=topic.id, tab="tests")

    old = topic.questions_per_test
    topic.questions_per_test = capacity
    topic.save(update_fields=["questions_per_test"])
    summary = rebalance_topic_tests(topic)
    extra = []
    if summary["created"]:
        extra.append(f"{summary['created']} yeni test")
    if summary["removed"]:
        extra.append(f"{summary['removed']} boş test silindi")
    extra_txt = f" ({', '.join(extra)})" if extra else ""
    messages.success(
        request,
        f"Test başına {old} → {capacity} soru. "
        f"{summary['questions']} soru {summary['tests']} teste dağıtıldı"
        f"{extra_txt}.",
    )
    return redirect("panel_topic", topic_id=topic.id, tab="tests")


@login_required
@staff_required
def panel_topic(
    request: HttpRequest, topic_id: int, tab: str = "lessons"
) -> HttpResponse:
    topic = get_object_or_404(
        Topic.objects.select_related("subject"), pk=topic_id
    )
    if tab not in {"lessons", "questions", "tests", "scenarios"}:
        tab = "lessons"

    lessons = topic.lessons.order_by("sort_order", "id")
    questions = topic.questions.select_related("scenario").order_by("-updated_at")
    tests = topic.tests.prefetch_related("questions").order_by("-created_at")
    scenarios = topic.question_scenarios.annotate(
        question_count=Count("questions")
    ).order_by("sort_order", "id")
    questions_published_count = questions.filter(is_published=True).count()

    return render(
        request,
        "panel/topic_workspace.html",
        {
            "topic": topic,
            "subject": topic.subject,
            "tab": tab,
            "lessons": lessons,
            "questions": questions,
            "questions_published_count": questions_published_count,
            "tests": tests,
            "scenarios": scenarios,
            "page_title": topic.name,
        },
    )


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_lesson_edit(
    request: HttpRequest, topic_id: int, lesson_id: int | None = None
) -> HttpResponse:
    topic = get_object_or_404(Topic, pk=topic_id)
    lesson = (
        get_object_or_404(TopicLesson, pk=lesson_id, topic=topic)
        if lesson_id
        else None
    )

    if request.method == "POST":
        title = request.POST.get("title", "").strip()
        body = request.POST.get("body", "").strip()
        sort_order = int(request.POST.get("sort_order") or 0)
        is_published = request.POST.get("is_published") == "on"
        if not title or not body:
            return HttpResponseBadRequest("Başlık ve içerik zorunlu.")

        if lesson is None:
            lesson = TopicLesson(topic=topic, public_id=_pid("les"))
        lesson.title = title
        lesson.body = body
        lesson.sort_order = sort_order
        lesson.is_published = is_published
        if request.FILES.get("image"):
            lesson.image = request.FILES["image"]
        lesson.save()
        return redirect("panel_topic", topic_id=topic.id, tab="lessons")

    return render(
        request,
        "panel/lesson_form.html",
        {
            "topic": topic,
            "subject": topic.subject,
            "lesson": lesson,
            "page_title": "Bilgi kartı" if lesson else "Yeni bilgi",
        },
    )


@login_required
@staff_required
@require_POST
def panel_lesson_delete(request: HttpRequest, lesson_id: int) -> HttpResponse:
    lesson = get_object_or_404(TopicLesson, pk=lesson_id)
    topic_id = lesson.topic_id
    lesson.delete()
    return redirect("panel_topic", topic_id=topic_id, tab="lessons")


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_scenario_edit(
    request: HttpRequest, topic_id: int, scenario_id: int | None = None
) -> HttpResponse:
    topic = get_object_or_404(Topic, pk=topic_id)
    scenario = (
        get_object_or_404(QuestionScenario, pk=scenario_id, topic=topic)
        if scenario_id
        else None
    )

    if request.method == "POST":
        title = request.POST.get("title", "").strip()
        stem = request.POST.get("stem", "").strip()
        try:
            sort_order = int(request.POST.get("sort_order") or 0)
        except (TypeError, ValueError):
            sort_order = 0
        is_published = request.POST.get("is_published") == "on"
        if not title or not stem:
            return HttpResponseBadRequest("Başlık ve ortak olay metni zorunlu.")

        if scenario is None:
            scenario = QuestionScenario(topic=topic)
        scenario.title = title
        scenario.stem = stem
        scenario.sort_order = max(0, sort_order)
        scenario.is_published = is_published
        scenario.save()
        messages.success(request, "Olay grubu kaydedildi.")
        return redirect("panel_topic", topic_id=topic.id, tab="scenarios")

    return render(
        request,
        "panel/scenario_form.html",
        {
            "topic": topic,
            "subject": topic.subject,
            "scenario": scenario,
            "page_title": "Olay grubu" if scenario else "Yeni olay grubu",
        },
    )


@login_required
@staff_required
@require_POST
def panel_scenario_delete(
    request: HttpRequest, scenario_id: int
) -> HttpResponse:
    scenario = get_object_or_404(QuestionScenario, pk=scenario_id)
    topic_id = scenario.topic_id
    scenario.delete()
    messages.success(request, "Olay grubu silindi. Bağlı sorular bağımsız kaldı.")
    return redirect("panel_topic", topic_id=topic_id, tab="scenarios")


def _apply_question_scenario(
    question: Question, topic: Topic, post
) -> None:
    raw = (post.get("scenario_id") or "").strip()
    if raw.isdigit():
        scenario = QuestionScenario.objects.filter(
            pk=int(raw), topic=topic
        ).first()
        question.scenario = scenario
    else:
        question.scenario = None
    try:
        question.scenario_order = max(0, int(post.get("scenario_order") or 0))
    except (TypeError, ValueError):
        question.scenario_order = 0


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_question_edit(
    request: HttpRequest, topic_id: int, question_id: int | None = None
) -> HttpResponse:
    url_topic = get_object_or_404(Topic, pk=topic_id)
    question = (
        get_object_or_404(Question, pk=question_id) if question_id else None
    )
    topic = question.topic if question else url_topic

    subjects = Subject.objects.filter(is_active=True).order_by(
        "sort_order", "name"
    )
    topics = topic.subject.topics.filter(is_active=True).order_by(
        "sort_order", "name"
    )

    if request.method == "POST":
        stem = request.POST.get("stem", "").strip()
        force_duplicate = request.POST.get("force_duplicate") == "1"
        map_template = request.POST.get("map_template", "").strip()
        try:
            map_markers = validate_map_markers(
                map_template,
                request.POST.get("map_markers", "[]"),
            )
        except ValidationError as exc:
            return HttpResponseBadRequest(" ".join(exc.messages))

        if not stem:
            return HttpResponseBadRequest("Soru metni zorunlu.")

        topic_raw = request.POST.get("topic_id") or str(topic.id)
        if not topic_raw.isdigit():
            return HttpResponseBadRequest("Geçerli bir konu seçin.")
        target_topic = get_object_or_404(
            Topic, pk=int(topic_raw), is_active=True
        )

        if question is None:
            question = Question(topic=target_topic, public_id=_pid("q"))
        elif question.topic_id != target_topic.id:
            for old_test in question.topic.tests.filter(questions=question):
                old_test.questions.remove(question)
            question.topic = target_topic

        question.subtopic = request.POST.get("subtopic", "").strip()
        question.stem = stem
        question.option_a = strip_option_emphasis(
            request.POST.get("option_a", "").strip()
        )
        question.option_b = strip_option_emphasis(
            request.POST.get("option_b", "").strip()
        )
        question.option_c = strip_option_emphasis(
            request.POST.get("option_c", "").strip()
        )
        question.option_d = strip_option_emphasis(
            request.POST.get("option_d", "").strip()
        )
        question.option_e = strip_option_emphasis(
            request.POST.get("option_e", "").strip()
        )
        if not all(
            [
                question.option_a,
                question.option_b,
                question.option_c,
                question.option_d,
                question.option_e,
            ]
        ):
            return HttpResponseBadRequest("KPSS soruları A–E beş şık gerektirir.")
        question.correct_option = request.POST.get("correct_option", "A")
        question.solution = request.POST.get("solution", "").strip()
        question.is_published = request.POST.get("is_published") == "on"
        question.osym_sordu = request.POST.get("osym_sordu") == "on"
        question.map_template = map_template
        question.map_markers = map_markers
        figure_svg = _sanitize_figure_svg(
            request.POST.get("figure_svg", "")
        )
        question.figure_svg = figure_svg

        image_hash = (request.POST.get("source_image_hash") or "").strip()
        if map_template:
            question.source_image_hash = ""
        elif image_hash:
            question.source_image_hash = image_hash

        c_hash = content_fingerprint(
            question.stem,
            question.option_a,
            question.option_b,
            question.option_c,
            question.option_d,
            question.option_e,
        )
        s_hash = stem_fingerprint(question.stem)
        dup, match = find_duplicate_question(
            content_hash=c_hash,
            stem_hash=s_hash,
            image_hash=question.source_image_hash,
            exclude_pk=question.pk,
            require_options=bool(
                question.option_a and question.option_b and question.option_c
            ),
        )
        if dup and not force_duplicate:
            info = duplicate_payload(dup, match)
            messages.error(
                request,
                "Bu soruyu daha önce yüklediniz — kayıt yapılmadı. "
                f"{info['message']}",
            )
            if question.pk:
                return redirect(
                    "panel_question_edit",
                    topic_id=target_topic.id,
                    question_id=question.id,
                )
            return redirect("panel_question_new", topic_id=target_topic.id)

        if map_template:
            rendered = render_map_question(map_template, map_markers)
            _discard_question_image(question)
            question.image.save(
                f"map_{question.public_id}.png",
                ContentFile(rendered),
                save=False,
            )
        else:
            # OCR kaynağı (ÖSYM tarama) uygulamaya gitmez; şekil SVG'dedir.
            _discard_question_image(question)

        _apply_question_scenario(question, target_topic, request.POST)
        question.save()
        refresh_question_embedding(question)

        assignment = request.POST.get("test_assignment", "auto")
        test = assign_question_to_test(question, target_topic, assignment)

        if dup and force_duplicate:
            messages.warning(
                request,
                f"Uyarı: benzer soru varken kaydedildi (önceki: {dup.public_id}).",
            )
        messages.success(
            request,
            f"Soru kaydedildi → {test.title} "
            f"({test.questions.count()}/{target_topic.questions_per_test or 20}). "
            "Uygulamalar birkaç saniye içinde güncellenir.",
        )
        return redirect("panel_topic", topic_id=target_topic.id, tab="questions")

    current_test = None
    selected_test_assignment = "auto"
    entry_mode = "edit" if question and question.pk else "manual"
    if question:
        current_test = (
            topic.tests.filter(questions=question)
            .order_by("-created_at")
            .first()
        )
    elif request.method == "GET":
        draft = _pop_ocr_draft(request, topic.id)
        if draft:
            question = _question_from_draft(draft)
            entry_mode = "ocr"
            selected_test_assignment = draft.get("test_assignment", "auto") or "auto"
            if str(selected_test_assignment).isdigit():
                current_test = topic.tests.filter(
                    pk=int(selected_test_assignment)
                ).first()
        else:
            prefs = _pop_manual_prefs(request, topic.id)
            if prefs:
                selected_test_assignment = prefs.get("test_assignment", "auto") or "auto"
                if str(selected_test_assignment).isdigit():
                    current_test = topic.tests.filter(
                        pk=int(selected_test_assignment)
                    ).first()
    test_dd = tests_for_dropdown(
        topic,
        selected_test_id=current_test.id if current_test else None,
    )
    scenarios = topic.question_scenarios.order_by("sort_order", "id")

    topic_subtopics = {
        str(t.pk): list(t.subtopics or [])
        for t in Topic.objects.filter(is_active=True).only("pk", "subtopics")
    }

    return render(
        request,
        "panel/question_form.html",
        {
            "topic": topic,
            "topics": topics,
            "subjects": subjects,
            "subject": topic.subject,
            "question": question,
            "test_dd": test_dd,
            "scenarios": scenarios,
            "current_test": current_test,
            "topic_subtopics_json": topic_subtopics,
            "map_markers_json": list(question.map_markers or [])
            if question
            else [],
            "map_templates_json": _map_templates_for_editor(),
            "map_template_choices": map_template_choices(),
            "page_title": "Soru düzenle"
            if question and question.pk
            else ("Görselden soru" if entry_mode == "ocr" else "Manuel soru ekle"),
            "selected_test_assignment": selected_test_assignment,
            "entry_mode": entry_mode,
        },
    )


@login_required
@staff_required
@require_POST
def panel_question_delete(
    request: HttpRequest, question_id: int
) -> HttpResponse:
    question = get_object_or_404(Question, pk=question_id)
    topic_id = question.topic_id
    question.delete()
    messages.success(request, "Soru silindi.")
    return redirect("panel_topic", topic_id=topic_id, tab="questions")


def _copy_question_image(source: Question, dest: Question) -> None:
    """Kaynak sorunun görselini yeni kayda dosya olarak kopyala."""
    if not source.image:
        return
    try:
        source.image.open("rb")
        data = source.image.read()
    except Exception:  # noqa: BLE001
        return
    finally:
        try:
            source.image.close()
        except Exception:  # noqa: BLE001
            pass
    if not data:
        return
    name = source.image.name.rsplit("/", 1)[-1]
    dest.image.save(
        f"copy_{dest.public_id}_{name}",
        ContentFile(data),
        save=False,
    )


@login_required
@staff_required
@require_POST
def panel_question_copy(
    request: HttpRequest, question_id: int
) -> HttpResponse:
    """Mevcut soruyu yeni public_id ile çoğalt — istatistikler sıfırlanır."""
    source = get_object_or_404(Question, pk=question_id)
    copy = Question(
        public_id=_pid("q"),
        topic=source.topic,
        subtopic=source.subtopic,
        stem=source.stem,
        figure_svg=source.figure_svg,
        map_template=source.map_template,
        map_markers=list(source.map_markers or []),
        option_a=source.option_a,
        option_b=source.option_b,
        option_c=source.option_c,
        option_d=source.option_d,
        option_e=source.option_e,
        correct_option=source.correct_option,
        solution=source.solution,
        is_published=source.is_published,
        difficulty=Question.DIFFICULTY_MEDIUM,
        osym_sordu=source.osym_sordu,
        content_hash=source.content_hash,
        stem_hash=source.stem_hash,
        source_image_hash=source.source_image_hash,
        scenario=source.scenario,
        scenario_order=(source.scenario_order + 1) if source.scenario_id else 0,
    )
    _copy_question_image(source, copy)
    copy.save()
    refresh_question_embedding(copy)
    test = assign_question_to_test(copy, source.topic, "auto")
    messages.success(
        request,
        f"Soru kopyalandı → {copy.public_id} ({test.title}). "
        "İstediğiniz alanları düzenleyip kaydedin.",
    )
    return redirect(
        "panel_question_edit",
        topic_id=source.topic_id,
        question_id=copy.id,
    )


@login_required
@staff_required
@require_POST
def panel_question_bulk_delete(
    request: HttpRequest, topic_id: int
) -> HttpResponse:
    """Konuya ait seçili soruları toplu sil."""
    topic = get_object_or_404(Topic, pk=topic_id)
    raw_ids = request.POST.getlist("ids")
    ids: list[int] = []
    for raw in raw_ids:
        try:
            ids.append(int(raw))
        except (TypeError, ValueError):
            continue
    if not ids:
        messages.warning(request, "Silmek için en az bir soru seçin.")
        return redirect("panel_topic", topic_id=topic.id, tab="questions")

    qs = Question.objects.filter(topic=topic, pk__in=ids)
    count = qs.count()
    if count:
        qs.delete()
        messages.success(request, f"{count} soru silindi.")
    else:
        messages.warning(request, "Seçilen sorular bulunamadı.")
    return redirect("panel_topic", topic_id=topic.id, tab="questions")


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_test_edit(
    request: HttpRequest, topic_id: int, test_id: int | None = None
) -> HttpResponse:
    topic = get_object_or_404(Topic, pk=topic_id)
    test = (
        get_object_or_404(TopicTest, pk=test_id, topic=topic)
        if test_id
        else None
    )
    pool = topic.questions.filter(is_published=True).order_by("public_id")

    if request.method == "POST":
        title = request.POST.get("title", "").strip()
        if not title:
            return HttpResponseBadRequest("Başlık zorunlu.")

        if test is None:
            test = TopicTest(topic=topic, public_id=_pid("test"))

        test.title = title
        test.description = request.POST.get("description", "").strip()
        test.time_limit_minutes = int(
            request.POST.get("time_limit_minutes") or 0
        )
        test.is_published = request.POST.get("is_published") == "on"
        test.save()
        selected = request.POST.getlist("questions")
        test.questions.set(Question.objects.filter(pk__in=selected, topic=topic))
        return redirect("panel_topic", topic_id=topic.id, tab="tests")

    selected_ids = set()
    if test:
        selected_ids = set(test.questions.values_list("pk", flat=True))

    pool_data = [
        {
            "id": q.id,
            "public_id": q.public_id,
            "stem": q.stem or "",
            "options": {
                "A": q.option_a or "",
                "B": q.option_b or "",
                "C": q.option_c or "",
                "D": q.option_d or "",
                "E": q.option_e or "",
            },
            "correct": q.correct_option or "A",
            "solution": q.solution or "",
        }
        for q in pool
    ]

    return render(
        request,
        "panel/test_form.html",
        {
            "topic": topic,
            "subject": topic.subject,
            "test": test,
            "pool": pool,
            "pool_data": pool_data,
            "selected_ids": selected_ids,
            "page_title": "Test düzenle" if test else "Yeni test",
        },
    )


@login_required
@staff_required
@require_POST
def panel_test_delete(request: HttpRequest, test_id: int) -> HttpResponse:
    test = get_object_or_404(TopicTest, pk=test_id)
    topic_id = test.topic_id
    test.delete()
    return redirect("panel_topic", topic_id=topic_id, tab="tests")


@login_required
@staff_required
def panel_announcement_list(request: HttpRequest) -> HttpResponse:
    items = Announcement.objects.all()[:100]
    ready, firebase_hint = firebase_ready()
    from .models import DeviceToken

    return render(
        request,
        "panel/announcements.html",
        {
            "announcements": items,
            "page_title": "Duyurular",
            "firebase_ready": ready,
            "firebase_hint": firebase_hint,
            "device_count": DeviceToken.objects.filter(is_active=True).count(),
        },
    )


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_announcement_edit(
    request: HttpRequest, announcement_id: int | None = None
) -> HttpResponse:
    item = (
        get_object_or_404(Announcement, pk=announcement_id)
        if announcement_id
        else None
    )
    if request.method == "POST":
        title = request.POST.get("title", "").strip()
        body = request.POST.get("body", "").strip()
        if not title:
            return HttpResponseBadRequest("Başlık zorunlu.")
        if item is None:
            item = Announcement()
        item.title = title
        item.body = body
        item.is_published = request.POST.get("is_published") == "on"
        if request.POST.get("clear_image") == "on":
            item.image = None
        elif request.FILES.get("image"):
            item.image = request.FILES["image"]
        if not item.body.strip() and not item.image:
            return HttpResponseBadRequest(
                "Metin veya fotoğraftan en az biri gerekli."
            )
        item.save()
        messages.success(request, "Duyuru kaydedildi.")
        if request.POST.get("send_push") == "1":
            return _send_and_redirect(request, item)
        return redirect("panel_announcement_edit", announcement_id=item.id)

    ready, firebase_hint = firebase_ready()
    return render(
        request,
        "panel/announcement_form.html",
        {
            "announcement": item,
            "page_title": "Duyuru düzenle" if item else "Yeni duyuru",
            "firebase_ready": ready,
            "firebase_hint": firebase_hint,
        },
    )


@login_required
@staff_required
@require_POST
def panel_announcement_delete(
    request: HttpRequest, announcement_id: int
) -> HttpResponse:
    item = get_object_or_404(Announcement, pk=announcement_id)
    item.delete()
    messages.success(request, "Duyuru silindi.")
    return redirect("panel_announcement_list")


@login_required
@staff_required
@require_POST
def panel_announcement_send(
    request: HttpRequest, announcement_id: int
) -> HttpResponse:
    item = get_object_or_404(Announcement, pk=announcement_id)
    return _send_and_redirect(request, item)


def _send_and_redirect(request: HttpRequest, item: Announcement) -> HttpResponse:
    result = send_announcement_push(item)
    if result.ok:
        messages.success(
            request,
            f"Bildirim gönderildi (başarılı: {result.success}"
            f"{', konu OK' if result.topic_ok else ''}"
            f", hata: {result.failure}).",
        )
    else:
        messages.error(request, result.error or "Bildirim gönderilemedi.")
    return redirect("panel_announcement_edit", announcement_id=item.id)


@login_required
@staff_required
def panel_users(request: HttpRequest) -> HttpResponse:
    q = (request.GET.get("q") or "").strip()
    users = AppUser.objects.all().order_by("-last_login_at", "-created_at")
    if q:
        from django.db.models import Q

        users = users.filter(
            Q(email__icontains=q)
            | Q(display_name__icontains=q)
            | Q(google_sub__icontains=q)
        )
    paginator = Paginator(users, 40)
    page = paginator.get_page(request.GET.get("page") or 1)
    return render(
        request,
        "panel/users.html",
        {
            "page_title": "Kullanıcılar",
            "page_obj": page,
            "query": q,
        },
    )


@login_required
@staff_required
@require_POST
def panel_user_grant_premium(request: HttpRequest, user_id: int) -> HttpResponse:
    from django.utils.dateparse import parse_datetime

    user = get_object_or_404(AppUser, pk=user_id)
    note = (request.POST.get("grant_note") or "").strip()
    expiry_raw = (request.POST.get("premium_expires_at") or "").strip()
    expires_at = parse_datetime(expiry_raw) if expiry_raw else None
    user.grant_free_premium(expires_at=expires_at, note=note)
    messages.success(
        request,
        f"{user.display_name or user.email} kullanıcısına premium tanımlandı.",
    )
    next_q = (request.POST.get("return_q") or "").strip()
    url = reverse("panel_users")
    if next_q:
        url = f"{url}?q={next_q}"
    return redirect(url)


@login_required
@staff_required
@require_POST
def panel_user_revoke_premium(request: HttpRequest, user_id: int) -> HttpResponse:
    user = get_object_or_404(AppUser, pk=user_id)
    label = user.display_name or user.email
    user.revoke_free_premium()
    messages.success(request, f"{label} kullanıcısının premiumu kaldırıldı.")
    next_q = (request.POST.get("return_q") or "").strip()
    url = reverse("panel_users")
    if next_q:
        url = f"{url}?q={next_q}"
    return redirect(url)


@login_required
@staff_required
def panel_exam_type_list(request: HttpRequest) -> HttpResponse:
    items = ExamType.objects.all()
    return render(
        request,
        "panel/exam_types.html",
        {
            "page_title": "Sınav tipleri",
            "exam_types": items,
        },
    )


def _exam_type_from_post(request: HttpRequest, item: ExamType | None) -> ExamType:
    from datetime import date as date_cls
    from django.utils.text import slugify
    from .models import EXAM_ICON_CHOICES, KPSS_TYPE_CHOICES

    name = (request.POST.get("name") or "").strip()
    slug = (request.POST.get("slug") or "").strip()
    if not slug:
        slug = slugify(name, allow_unicode=False) or "sinav"
    short_name = (request.POST.get("short_name") or "").strip()
    description = (request.POST.get("description") or "").strip()
    raw_date = (request.POST.get("exam_date") or "").strip()
    exam_date = None
    if raw_date:
        try:
            exam_date = date_cls.fromisoformat(raw_date)
        except ValueError:
            exam_date = None
    content_type = (request.POST.get("content_type") or "lisans").strip()
    icon_key = (request.POST.get("icon_key") or "school").strip()
    try:
        sort_order = int(request.POST.get("sort_order") or 0)
    except ValueError:
        sort_order = 0
    yearly_repeat = request.POST.get("yearly_repeat") == "on"
    even_years_only = request.POST.get("even_years_only") == "on"
    is_active = request.POST.get("is_active") == "on"

    valid_content = {c[0] for c in KPSS_TYPE_CHOICES}
    valid_icons = {c[0] for c in EXAM_ICON_CHOICES}
    if content_type not in valid_content:
        content_type = "lisans"
    if icon_key not in valid_icons:
        icon_key = "school"

    obj = item or ExamType()
    obj.name = name
    obj.slug = slug
    obj.short_name = short_name
    obj.description = description
    obj.exam_date = exam_date
    obj.content_type = content_type
    obj.icon_key = icon_key
    obj.sort_order = sort_order
    obj.yearly_repeat = yearly_repeat
    obj.even_years_only = even_years_only
    obj.is_active = is_active
    return obj


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_exam_type_edit(
    request: HttpRequest, exam_id: int | None = None
) -> HttpResponse:
    from .models import EXAM_ICON_CHOICES, KPSS_TYPE_CHOICES

    item = get_object_or_404(ExamType, pk=exam_id) if exam_id else None
    if request.method == "POST":
        obj = _exam_type_from_post(request, item)
        if not obj.name:
            messages.error(request, "Sınav adı gerekli.")
            item = obj
        elif not obj.exam_date:
            messages.error(request, "Sınav tarihi gerekli.")
            item = obj
        else:
            try:
                obj.save()
            except Exception as exc:  # noqa: BLE001
                messages.error(request, f"Kaydedilemedi: {exc}")
                item = obj
            else:
                messages.success(request, f"{obj.name} kaydedildi.")
                return redirect("panel_exam_type_list")

    return render(
        request,
        "panel/exam_type_form.html",
        {
            "page_title": "Sınav düzenle" if exam_id else "Yeni sınav tipi",
            "exam": item,
            "content_types": KPSS_TYPE_CHOICES,
            "icon_choices": EXAM_ICON_CHOICES,
        },
    )


@login_required
@staff_required
@require_POST
def panel_exam_type_delete(request: HttpRequest, exam_id: int) -> HttpResponse:
    item = get_object_or_404(ExamType, pk=exam_id)
    label = item.name
    item.delete()
    messages.success(request, f"{label} silindi.")
    return redirect("panel_exam_type_list")
