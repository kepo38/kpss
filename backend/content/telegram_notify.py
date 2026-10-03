"""Telegram admin bildirimleri — soru hata raporu vb."""

from __future__ import annotations

import logging

from django.conf import settings
from django.urls import reverse

from .models import ERROR_REPORT_CATEGORY_CHOICES, QuestionErrorReport
from .telegram_bot import send_message, telegram_configured

logger = logging.getLogger(__name__)

_CATEGORY_LABELS = dict(ERROR_REPORT_CATEGORY_CHOICES)


def _admin_chat_ids() -> list[int]:
    return list(getattr(settings, "TELEGRAM_ALLOWED_USER_IDS", []) or [])


def notify_admins(text: str) -> None:
    if not telegram_configured():
        return
    for chat_id in _admin_chat_ids():
        send_message(chat_id, text)


def _category_label(category: str) -> str:
    return _CATEGORY_LABELS.get(category, category)


def _truncate(text: str, max_len: int = 300) -> str:
    text = (text or "").strip()
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def format_error_report_message(
    report: QuestionErrorReport,
    *,
    panel_url: str | None = None,
) -> str:
    question = report.question
    topic = question.topic
    subject = topic.subject
    user = report.user

    lines = [
        "⚠️ Soru hata bildirimi",
        "",
        f"Soru: {question.public_id}",
        f"Ders: {subject.name} / {topic.name}",
        f"Tür: {_category_label(report.category)}",
    ]
    display = (user.display_name or "").strip()
    email = (user.email or "").strip()
    if display and email:
        lines.append(f"Öğrenci: {display} ({email})")
    elif display:
        lines.append(f"Öğrenci: {display}")
    elif email:
        lines.append(f"Öğrenci: {email}")

    note = _truncate(report.note)
    if note:
        lines.extend(["", f"Not: {note}"])

    url = panel_url or reverse("panel_error_reports")
    lines.extend(["", f"Panel: {url}"])
    return "\n".join(lines)


def notify_error_report(
    report: QuestionErrorReport,
    *,
    request=None,
) -> None:
    try:
        report = QuestionErrorReport.objects.select_related(
            "question__topic__subject",
            "user",
        ).get(pk=report.pk)
        panel_url = None
        if request is not None:
            panel_url = request.build_absolute_uri(reverse("panel_error_reports"))
        message = format_error_report_message(report, panel_url=panel_url)
        notify_admins(message)
    except Exception:
        logger.exception(
            "Telegram error report notification failed report_id=%s",
            report.pk,
        )
