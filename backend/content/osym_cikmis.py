"""Panel — ÖSYM çıkmış soru adı önerileri."""

from __future__ import annotations

from django.db.models import F
from django.utils import timezone

from .models import OsymCikmisOneri, Question


def normalize_osym_cikmis_label(raw: str) -> str:
    return " ".join((raw or "").strip().split())


def record_osym_cikmis_oneri(label: str) -> None:
    normalized = normalize_osym_cikmis_label(label)
    if not normalized:
        return
    obj, created = OsymCikmisOneri.objects.get_or_create(label=normalized)
    if not created:
        OsymCikmisOneri.objects.filter(pk=obj.pk).update(
            use_count=F("use_count") + 1,
            last_used=timezone.now(),
        )


def osym_cikmis_suggestions(*, limit: int = 60) -> list[str]:
    """Önce sık kullanılan öneriler, sonra sorulardaki benzersiz etiketler."""
    seen: set[str] = set()
    out: list[str] = []
    for label in OsymCikmisOneri.objects.order_by(
        "-use_count", "-last_used", "label"
    ).values_list("label", flat=True)[:limit]:
        key = label.casefold()
        if key in seen:
            continue
        seen.add(key)
        out.append(label)
    remaining = max(0, limit - len(out))
    if remaining:
        for label in (
            Question.objects.exclude(osym_cikmis_adi="")
            .order_by("-updated_at")
            .values_list("osym_cikmis_adi", flat=True)
            .distinct()[: remaining * 3]
        ):
            normalized = normalize_osym_cikmis_label(label)
            if not normalized:
                continue
            key = normalized.casefold()
            if key in seen:
                continue
            seen.add(key)
            out.append(normalized)
            if len(out) >= limit:
                break
    return out
