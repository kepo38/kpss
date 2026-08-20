"""Soru benzersizlik — içerik ve kaynak görsel parmak izi."""

from __future__ import annotations

import hashlib
import io
import logging
import re
import unicodedata
from difflib import SequenceMatcher
from typing import BinaryIO

from django.urls import reverse

from .models import Question

logger = logging.getLogger(__name__)

_PHASH_BITS = 64  # 8×8 DCT-based perceptual hash → 16-char hex
_HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
_EDITOR_NOTE = re.compile(r"\(\s*not\s*:.*?\)", re.IGNORECASE | re.DOTALL)
_MAP_PLACEHOLDER = re.compile(r"\[\s*harita\s*\]", re.IGNORECASE)
_NEAR_STEM_RATIO = 0.68


def normalize_question_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", value or "")
    text = _HTML_COMMENT.sub(" ", text)
    text = _EDITOR_NOTE.sub(" ", text)
    text = text.casefold().replace("\u0307", "")
    text = _MAP_PLACEHOLDER.sub(" ", text)
    # OCR / markdown gürültüsü
    text = re.sub(r"[*_`~#]+", "", text)
    text = re.sub(r"[^\w\sçğıöşüâîû]", " ", text, flags=re.UNICODE)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def options_fingerprint(
    option_a: str = "",
    option_b: str = "",
    option_c: str = "",
    option_d: str = "",
    option_e: str = "",
) -> str:
    parts = [
        normalize_question_text(option_a),
        normalize_question_text(option_b),
        normalize_question_text(option_c),
        normalize_question_text(option_d),
        normalize_question_text(option_e),
    ]
    filled = [part for part in parts if len(part) >= 3]
    if len(filled) < 4:
        return ""
    return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


def stem_similarity(left: str, right: str) -> float:
    a = normalize_question_text(left)
    b = normalize_question_text(right)
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b).ratio()


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


def image_phash(source: BinaryIO | bytes) -> str:
    """Perceptual hash (average hash) — 16 hex karakter. Küçük düzenlemelere dayanıklı."""
    try:
        from PIL import Image
    except ImportError:
        logger.warning("Pillow yüklü değil; phash atlanıyor.")
        return ""

    try:
        if isinstance(source, (bytes, bytearray)):
            img = Image.open(io.BytesIO(source))
        else:
            if hasattr(source, "seek"):
                try:
                    source.seek(0)
                except Exception:
                    pass
            img = Image.open(source)
            if hasattr(source, "seek"):
                try:
                    source.seek(0)
                except Exception:
                    pass

        img = img.convert("L").resize((8, 8), Image.LANCZOS)
        pixels = list(img.getdata())
        avg = sum(pixels) / len(pixels)

        hash_int = 0
        for p in pixels:
            hash_int = (hash_int << 1) | (1 if p > avg else 0)
        return f"{hash_int:016x}"
    except Exception:
        logger.exception("phash hesaplanamadı")
        return ""


def phash_hamming(h1: str, h2: str) -> int:
    """İki 16-hex phash arası Hamming mesafesi (0 = aynı, 64 = tamamen farklı)."""
    if not h1 or not h2 or len(h1) != 16 or len(h2) != 16:
        return _PHASH_BITS
    try:
        xor = int(h1, 16) ^ int(h2, 16)
        return bin(xor).count("1")
    except ValueError:
        return _PHASH_BITS


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
    image_phash_hex: str = "",
    exclude_pk: int | None = None,
    require_options: bool = False,
    stem: str = "",
    option_a: str = "",
    option_b: str = "",
    option_c: str = "",
    option_d: str = "",
    option_e: str = "",
) -> tuple[Question | None, str]:
    """
    Dönüş: (soru, eşleşme türü)
    eşleşme: image | image_similar | content | stem | ""
    """
    qs = Question.objects.select_related("topic", "topic__subject")
    if exclude_pk:
        qs = qs.exclude(pk=exclude_pk)

    # Tam görsel hash eşleşmesi
    if image_hash:
        hit = qs.filter(source_image_hash=image_hash).exclude(
            source_image_hash=""
        ).first()
        if hit:
            return hit, "image"

    # phash yalnızca kayıt/analitik için tutulur; otomatik engelleme yapmaz.
    # ÖSYM şablonlu farklı sorular 8x8 average hash'te ≤2 bit yakın çıkabiliyor.

    if content_hash:
        hit = qs.filter(content_hash=content_hash).exclude(content_hash="").first()
        if hit:
            return hit, "content"

    # Stem-only: yalnızca şıklar doluysa (placeholder OCR çakışmasını önle)
    if stem_hash and require_options:
        hit = qs.filter(stem_hash=stem_hash).exclude(stem_hash="").first()
        if hit:
            return hit, "stem"

    near = _find_by_options_and_stem(
        qs,
        stem=stem,
        option_a=option_a,
        option_b=option_b,
        option_c=option_c,
        option_d=option_d,
        option_e=option_e,
    )
    if near:
        return near, "content"

    return None, ""


def _find_by_options_and_stem(
    qs,
    *,
    stem: str,
    option_a: str,
    option_b: str,
    option_c: str,
    option_d: str,
    option_e: str,
) -> Question | None:
    incoming_opts = options_fingerprint(
        option_a, option_b, option_c, option_d, option_e
    )
    if not incoming_opts:
        return None
    needle = (option_a or "").strip()[:12]
    candidates = qs
    if len(needle) >= 4:
        candidates = candidates.filter(option_a__icontains=needle)
    incoming_stem = normalize_question_text(stem)
    for question in candidates.iterator():
        stored_opts = options_fingerprint(
            question.option_a,
            question.option_b,
            question.option_c,
            question.option_d,
            question.option_e,
        )
        if stored_opts != incoming_opts:
            continue
        if not incoming_stem:
            return question
        if stem_similarity(stem, question.stem) >= _NEAR_STEM_RATIO:
            return question
    return None


def duplicate_payload(question: Question, match: str) -> dict:
    topic = question.topic
    edit_url = reverse(
        "panel_question_edit",
        kwargs={"topic_id": topic.id, "question_id": question.id},
    )
    labels = {
        "image": "aynı görsel",
        "image_similar": "çok benzer görsel (düzenlenmiş olabilir)",
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
    image_phash_hex: str | None = None,
) -> None:
    content, stem = fingerprints_for_question(question)
    question.content_hash = content
    question.stem_hash = stem
    if image_hash is not None:
        question.source_image_hash = image_hash or ""
    if image_phash_hex is not None:
        question.source_image_phash = image_phash_hex or ""
