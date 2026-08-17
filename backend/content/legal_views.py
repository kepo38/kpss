"""Herkese açık yasal sayfalar (mağaza kayıt URL'leri)."""

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render
from django.utils import timezone


def privacy_policy(request: HttpRequest) -> HttpResponse:
    """Play Store / App Store gizlilik politikası."""
    return render(
        request,
        "legal/privacy_policy.html",
        {
            "page_title": "Gizlilik Politikası",
            "app_name": "Hedef Kamu",
            "updated_at": timezone.localdate(),
            "contact_email": "destek@hedefkamu.app",
        },
    )
