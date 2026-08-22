"""Panel — ÖSYM Çıkmış Sorular arşiv yöneticisi."""

from __future__ import annotations

from urllib.parse import unquote

from django.contrib.auth.decorators import login_required, user_passes_test
from django.http import HttpRequest, HttpResponse, HttpResponseNotFound
from django.shortcuts import render

from content.models import Question

from .osym_archive import (
    archive_families,
    archive_key_from_label,
    archive_years,
    build_archive_summary,
    build_archive_tree,
    build_extra_groups,
    questions_for_archive_key,
)

staff_required = user_passes_test(lambda u: u.is_active and u.is_staff)


def _parse_year_filter(raw: str) -> int | None:
    value = (raw or "").strip()
    if not value:
        return None
    try:
        year = int(value)
    except ValueError:
        return None
    if year < 2000 or year > 2100:
        return None
    return year


@login_required
@staff_required
def panel_osym_archive(request: HttpRequest) -> HttpResponse:
    family = (request.GET.get("family") or "").strip()
    year_filter = _parse_year_filter(request.GET.get("year") or "")
    show_missing_only = request.GET.get("missing") == "1"

    tree = build_archive_tree(
        family_filter=family,
        year_filter=year_filter,
    )
    if show_missing_only:
        for year_group in tree:
            filtered_exams = []
            for exam in year_group.exams:
                sessions = [s for s in exam.sessions if s.status == "missing"]
                if sessions:
                    filtered_exams.append(
                        type(exam)(
                            family=exam.family,
                            exam_name=exam.exam_name,
                            sessions=sessions,
                        )
                    )
            year_group.exams = filtered_exams
        tree = [g for g in tree if g.exams]

    summary = build_archive_summary()
    extras = build_extra_groups()
    untagged_questions = (
        Question.objects.filter(osym_sordu=True, osym_cikmis_adi="")
        .select_related("topic", "topic__subject")
        .order_by("-updated_at")[:20]
    )

    return render(
        request,
        "panel/osym_archive.html",
        {
            "page_title": "ÖSYM Çıkmış Sorular",
            "tree": tree,
            "summary": summary,
            "extras": extras,
            "untagged_questions": untagged_questions,
            "families": archive_families(),
            "years": archive_years(),
            "selected_family": family,
            "selected_year": year_filter,
            "show_missing_only": show_missing_only,
            "label_format_hint": "2025 KPSS Lisans · Genel Yetenek - Genel Kültür",
        },
    )


@login_required
@staff_required
def panel_osym_archive_detail(request: HttpRequest, label: str) -> HttpResponse:
    archive_key = archive_key_from_label(unquote(label))
    if not archive_key:
        return HttpResponseNotFound("Geçersiz arşiv etiketi.")

    published_only = request.GET.get("published") == "1"
    questions = questions_for_archive_key(archive_key, published_only=published_only)
    active_count = sum(1 for q in questions if q.is_published)
    total_count = len(questions)

    return render(
        request,
        "panel/osym_archive_detail.html",
        {
            "page_title": f"ÖSYM · {archive_key}",
            "archive_key": archive_key,
            "questions": questions,
            "active_count": active_count,
            "total_count": total_count,
            "published_only": published_only,
        },
    )
