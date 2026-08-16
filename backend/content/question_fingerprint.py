"""Soru benzersizlik — içerik ve kaynak görsel parmak izi."""

from __future__ import annotations

import hashlib
import re
import unicodedata
from typing import BinaryIO

from django.urls import reverse

from .models import Question


def normalize_question_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", value or "")
    text = text.casefold()
    # OCR / markdown gürültüsü
    text = re.sub(r"[*_`~#]+", "", text)
    text = re.sub(r"[^\w\sçğıöşüâîû]", " ", text, flags=re.UNICODE)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def content_fingerprint(
    stem: str,
    option_a: str = "",
    option_b: str = "",
    option_c: str = "",
    option_d: str = "",
    option_e: str = "",
) -> str:
    parts = [
        normalize_question_text(stem),
        normalize_question_text(option_a),
        normalize_question_text(option_b),
        normalize_question_text(option_c),
        normalize_question_text(option_d),
        normalize_question_text(option_e),
    ]
    payload = "|".join(parts)
    if not any(parts):
        return ""
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def stem_fingerprint(stem: str) -> str:
    normalized = normalize_question_text(stem)
    if len(normalized) < 24:
        return ""
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def image_fingerprint(source: BinaryIO | bytes) -> str:
    digest = hashlib.sha256()
    if isinstance(source, (bytes, bytearray)):
        digest.update(source)
        return digest.hexdigest()

    pos = None
    if hasattr(source, "tell") and hasattr(source, "seek"):
        try:
            pos = source.tell()
            source.seek(0)
        except Exception:
            pos = None

    if hasattr(source, "chunks"):
        for chunk in source.chunks():
            digest.update(chunk)
    else:
        while True:
            chunk = source.read(1024 * 64)
            if not chunk:
                break
            digest.update(chunk)

    if hasattr(source, "seek"):
        try:
            source.seek(0)
        except Exception:
            pass

    return digest.hexdigest()


def fingerprints_for_question(question: Question) -> tuple[str, str]:
    content = content_fingerprint(
        question.stem,
        question.option_a,
        question.option_b,
        question.option_c,
        question.option_d,
        question.option_e,
    )
    stem = stem_fingerprint(question.stem)
    return content, stem


def find_duplicate_question(
    *,
    content_hash: str = "",
    stem_hash: str = "",
    image_hash: str = "",
    exclude_pk: int | None = None,
    require_options: bool = False,
) -> tuple[Question | None, str]:
    """
    Dönüş: (soru, eşleşme türü)
    eşleşme: image | content | stem | ""
    """
    qs = Question.objects.select_related("topic", "topic__subject")
    if exclude_pk:
        qs = qs.exclude(pk=exclude_pk)

    if image_hash:
        hit = qs.filter(source_image_hash=image_hash).exclude(
            source_image_hash=""
        ).first()
        if hit:
            return hit, "image"

    if content_hash:
        hit = qs.filter(content_hash=content_hash).exclude(content_hash="").first()
        if hit:
            return hit, "content"

    # Stem-only: yalnızca şıklar doluysa (placeholder OCR çakışmasını önle)
    if stem_hash and require_options:
        hit = qs.filter(stem_hash=stem_hash).exclude(stem_hash="").first()
        if hit:
            return hit, "stem"

    return None, ""


def duplicate_payload(question: Question, match: str) -> dict:
    topic = question.topic
    edit_url = reverse(
        "panel_question_edit",
        kwargs={"topic_id": topic.id, "question_id": question.id},
    )
    labels = {
        "image": "aynı görsel",
        "content": "aynı soru metni ve şıklar",
        "stem": "aynı soru metni",
    }
    return {
        "id": question.id,
        "public_id": question.public_id,
        "stem_preview": (question.stem or "")[:160],
        "topic_name": topic.name,
        "subject_name": topic.subject.name,
        "edit_url": edit_url,
        "match": match,
        "match_label": labels.get(match, "benzer içerik"),
        "message": (
            f"Bu soru daha önce yüklendi ({labels.get(match, 'benzer')}): "
            f"{topic.subject.name} · {topic.name} · {question.public_id}"
        ),
    }


def apply_fingerprints(
    question: Question,
    *,
    image_hash: str | None = None,
) -> None:
    content, stem = fingerprints_for_question(question)
    question.content_hash = content
    question.stem_hash = stem
    if image_hash is not None:
        question.source_image_hash = image_hash or ""
