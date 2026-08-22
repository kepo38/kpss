"""Telegram webhook endpoint."""

from __future__ import annotations

import json
import logging

from django.conf import settings
from django.http import HttpRequest, HttpResponse, HttpResponseForbidden
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .telegram_bot import handle_update, telegram_configured

logger = logging.getLogger(__name__)


@csrf_exempt
@require_POST
def telegram_webhook(request: HttpRequest, secret: str) -> HttpResponse:
    expected = getattr(settings, "TELEGRAM_WEBHOOK_SECRET", "") or ""
    if not expected or secret != expected:
        return HttpResponseForbidden("invalid secret")
    if not telegram_configured():
        return HttpResponse(status=503)

    try:
        payload = json.loads(request.body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return HttpResponse(status=400)

    try:
        handle_update(payload)
    except Exception:
        logger.exception("Telegram webhook handler failed")
    return HttpResponse("ok")
