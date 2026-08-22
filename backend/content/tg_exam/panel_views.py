"""Panel — TG Deneme Oluşturucu (ExamPack / TopicTest'ten bağımsız)."""

from __future__ import annotations

import json

from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.db import transaction
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_http_methods, require_POST

from content.models import KPSS_TYPE_CHOICES, Question, TgExam

from .announcements import format_tr_exam_moment
from .constants import TG_EXAM_DURATION_MINUTES
from .distribution import DEFAULT_TG_EXAM_DISTRIBUTION
from .generator import TgExamGeneratorError, TgExamGeneratorService

staff_required = user_passes_test(lambda u: u.is_active and u.is_staff)


def _parse_panel_datetime(raw: str):
    from django.utils.dateparse import parse_datetime

    value = (raw or "").strip()
    if not value:
        return None
    if "T" in value and len(value) == 16:
        value = f"{value}:00"
    return parse_datetime(value)


def _tg_exam_from_post(request: HttpRequest, item: TgExam | None) -> TgExam:
    obj = item or TgExam()
    obj.title = (request.POST.get("title") or "").strip()[:200]
    kpss = (request.POST.get("kpss_type") or "lisans").strip()
    valid = {c[0] for c in KPSS_TYPE_CHOICES}
    obj.kpss_type = kpss if kpss in valid else "lisans"
    obj.start_at = _parse_panel_datetime(request.POST.get("start_at") or "")
    obj.end_at = _parse_panel_datetime(request.POST.get("end_at") or "")
    try:
        obj.duration_minutes = max(
            30,
            int(request.POST.get("duration_minutes") or TG_EXAM_DURATION_MINUTES),
        )
    except (TypeError, ValueError):
        obj.duration_minutes = TG_EXAM_DURATION_MINUTES
    return obj


def _questions_for_preview(question_ids: list[str]) -> list[dict]:
    if not question_ids:
        return []
    by_id = {
        q.public_id: q
        for q in Question.objects.filter(public_id__in=question_ids).select_related(
            "topic",
            "topic__subject",
        )
    }
    rows: list[dict] = []
    for index, qid in enumerate(question_ids):
        q = by_id.get(qid)
        if q is None:
            rows.append(
                {
                    "index": index,
                    "public_id": qid,
                    "subject": "—",
                    "subtopic": "",
                    "stem_preview": "(Soru bulunamadı veya yayından kaldırıldı)",
                    "missing": True,
                }
            )
            continue
        rows.append(
            {
                "index": index,
                "public_id": q.public_id,
                "subject": q.topic.subject.name,
                "subtopic": q.subtopic or "—",
                "stem_preview": (q.stem or "")[:160],
                "missing": False,
                "difficulty": q.get_difficulty_display(),
                "tg_cooldown": q.tg_exam_cooldown_counter,
                "last_tg_used": q.last_used_in_tg_exam_at,
            }
        )
    return rows


@login_required
@staff_required
def panel_tg_exam_list(request: HttpRequest) -> HttpResponse:
    exams = TgExam.objects.order_by("-created_at")
    return render(
        request,
        "panel/tg_exam_list.html",
        {
            "page_title": "TG Deneme Oluşturucu",
            "exams": exams,
            "distribution_json": json.dumps(
                DEFAULT_TG_EXAM_DISTRIBUTION,
                ensure_ascii=False,
                indent=2,
            ),
        },
    )


@login_required
@staff_required
@require_http_methods(["GET", "POST"])
def panel_tg_exam_edit(
    request: HttpRequest,
    exam_id: int | None = None,
) -> HttpResponse:
    exam = get_object_or_404(TgExam, pk=exam_id) if exam_id else None

    if request.method == "POST":
        action = (request.POST.get("action") or "save").strip()
        obj = _tg_exam_from_post(request, exam)

        if action == "generate":
            if exam is None:
                messages.error(request, "Önce temel ayarları kaydedin.")
                return redirect("panel_tg_exam_new")
            if not obj.title or not obj.start_at or not obj.end_at:
                messages.error(request, "Deneme adı ve tarihler gerekli.")
            elif obj.end_at <= obj.start_at:
                messages.error(request, "Bitiş tarihi başlangıçtan sonra olmalı.")
            else:
                try:
                    service = TgExamGeneratorService(
                        kpss_type=exam.kpss_type,
                        exclude_exam_id=exam.pk,
                    )
                    question_ids = service.generate()
                except TgExamGeneratorError as exc:
                    messages.error(request, str(exc))
                else:
                    exam.title = obj.title
                    exam.kpss_type = obj.kpss_type
                    exam.start_at = obj.start_at
                    exam.end_at = obj.end_at
                    exam.duration_minutes = obj.duration_minutes
                    exam.question_ids = question_ids
                    exam.is_published = False
                    exam.save()
                    messages.success(
                        request,
                        f"{len(question_ids)} soru otomatik atandı. Önizlemeyi kontrol edin.",
                    )
            return redirect("panel_tg_exam_edit", exam_id=exam.pk)

        if not obj.title:
            messages.error(request, "Deneme adı gerekli.")
        elif not obj.start_at or not obj.end_at:
            messages.error(request, "Başlangıç ve bitiş tarihi gerekli.")
        elif obj.end_at <= obj.start_at:
            messages.error(request, "Bitiş tarihi başlangıçtan sonra olmalı.")
        else:
            obj.save()
            messages.success(request, "Temel ayarlar kaydedildi.")
            if exam is None:
                return redirect("panel_tg_exam_edit", exam_id=obj.pk)
            return redirect("panel_tg_exam_edit", exam_id=exam.pk)

        exam = obj

    question_rows = _questions_for_preview(list(exam.question_ids or []) if exam else [])
    expected_total = TgExamGeneratorService().slot_count()

    return render(
        request,
        "panel/tg_exam_form.html",
        {
            "page_title": "TG deneme düzenle" if exam_id else "Yeni TG deneme",
            "exam": exam,
            "kpss_types": KPSS_TYPE_CHOICES,
            "question_rows": question_rows,
            "expected_total": expected_total,
            "distribution_json": json.dumps(
                DEFAULT_TG_EXAM_DISTRIBUTION,
                ensure_ascii=False,
                indent=2,
            ),
        },
    )


@login_required
@staff_required
@require_POST
def panel_tg_exam_replace_question(
    request: HttpRequest,
    exam_id: int,
) -> HttpResponse:
    exam = get_object_or_404(TgExam, pk=exam_id)
    if exam.is_published:
        messages.warning(
            request, "Yayındaki deneme düzenlenemez — önce yayından kaldırın."
        )
        return redirect("panel_tg_exam_edit", exam_id=exam.pk)

    old_id = (request.POST.get("question_id") or "").strip()
    if not old_id:
        messages.error(request, "Soru kimliği gerekli.")
        return redirect("panel_tg_exam_edit", exam_id=exam.pk)

    try:
        service = TgExamGeneratorService(
            kpss_type=exam.kpss_type,
            exclude_exam_id=exam.pk,
        )
        updated = service.replace_by_question(list(exam.question_ids or []), old_id)
    except TgExamGeneratorError as exc:
        messages.error(request, str(exc))
    else:
        exam.question_ids = updated
        exam.save(update_fields=["question_ids", "updated_at"])
        messages.success(request, f"{old_id} rastgele başka bir soruyla değiştirildi.")

    return redirect("panel_tg_exam_edit", exam_id=exam.pk)


@login_required
@staff_required
@require_POST
def panel_tg_exam_publish(request: HttpRequest, exam_id: int) -> HttpResponse:
    exam = get_object_or_404(TgExam, pk=exam_id)
    question_ids = list(exam.question_ids or [])

    if not question_ids:
        messages.error(request, "Yayınlamadan önce soruları oluşturun.")
        return redirect("panel_tg_exam_edit", exam_id=exam.pk)

    expected = TgExamGeneratorService().slot_count()
    if len(question_ids) != expected:
        messages.warning(
            request,
            f"Beklenen {expected} soru, mevcut {len(question_ids)} soru.",
        )

    with transaction.atomic():
        exam.is_published = True
        exam.save(update_fields=["is_published", "updated_at"])

    due_at = exam.announcement_push_due_at
    due_label = format_tr_exam_moment(due_at)
    messages.success(
        request,
        f"“{exam.title}” yayında — mobil Denemeler sekmesinde görünür. "
        f"Tüm kullanıcılara duyuru bildirimi {due_label} tarihinde (sınavdan 2 saat önce) otomatik gidecek.",
    )

    return redirect("panel_tg_exam_list")


@login_required
@staff_required
@require_POST
def panel_tg_exam_unpublish(request: HttpRequest, exam_id: int) -> HttpResponse:
    exam = get_object_or_404(TgExam, pk=exam_id)
    exam.is_published = False
    exam.save(update_fields=["is_published", "updated_at"])
    messages.success(request, f"“{exam.title}” yayından kaldırıldı.")
    return redirect("panel_tg_exam_edit", exam_id=exam.pk)


@login_required
@staff_required
@require_POST
def panel_tg_exam_delete(request: HttpRequest, exam_id: int) -> HttpResponse:
    exam = get_object_or_404(TgExam, pk=exam_id)
    if exam.attempts.exists():
        messages.error(
            request,
            "Katılım kaydı olan deneme silinemez. Yayından kaldırın.",
        )
        return redirect("panel_tg_exam_edit", exam_id=exam.pk)
    title = exam.title
    exam.delete()
    messages.success(request, f"“{title}” silindi.")
    return redirect("panel_tg_exam_list")
