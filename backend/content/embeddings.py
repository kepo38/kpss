"""Soru vektör gömme ve kosinüs benzerliği.

OPENAI_API_KEY varsa `text-embedding-3-small`; yoksa yerel hash vektörü.
SQLite'da JSON saklanır; Postgres + pgvector ölçek için sonraki adım.
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import re
import urllib.error
import urllib.request
from typing import Iterable

from django.conf import settings

logger = logging.getLogger(__name__)

LOCAL_DIM = 64
DEFAULT_LIMIT = 5
_TOKEN_RE = re.compile(r"[a-zA-Z0-9ğüşıöçĞÜŞİÖÇ]+", re.UNICODE)


def embedding_text_for(question) -> str:
    parts = [
        getattr(question.topic.subject, "name", "") if question.topic_id else "",
        getattr(question.topic, "name", "") if question.topic_id else "",
        question.subtopic or "",
        getattr(question.scenario, "stem", "") if question.scenario_id else "",
        question.stem or "",
        question.option_a or "",
        question.option_b or "",
        question.option_c or "",
        question.option_d or "",
        question.option_e or "",
    ]
    return "\n".join(part.strip() for part in parts if part and part.strip())


def text_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def cosine_similarity(left: list[float], right: list[float]) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    dot = 0.0
    left_norm = 0.0
    right_norm = 0.0
    for a, b in zip(left, right):
        dot += a * b
        left_norm += a * a
        right_norm += b * b
    if left_norm <= 0 or right_norm <= 0:
        return 0.0
    return dot / math.sqrt(left_norm * right_norm)


def local_embedding(text: str, dim: int = LOCAL_DIM) -> list[float]:
    """Kelime örtüşmesine duyarlı, anahtarsız deterministik vektör."""
    vector = [0.0] * dim
    tokens = _TOKEN_RE.findall(text.casefold())
    if not tokens:
        tokens = ["empty"]
    for token in tokens:
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        index = int.from_bytes(digest[:2], "big") % dim
        sign = 1.0 if digest[2] % 2 == 0 else -1.0
        vector[index] += sign
    return _l2_normalize(vector)


def _l2_normalize(vector: list[float]) -> list[float]:
    norm = math.sqrt(sum(v * v for v in vector))
    if norm <= 0:
        return vector
    return [v / norm for v in vector]


def embed_text(text: str) -> tuple[list[float], str]:
    """(vektör, model_adı) — OpenAI varsa onu, yoksa yerel."""
    openai_key = getattr(settings, "OPENAI_API_KEY", "") or ""
    if openai_key:
        model = getattr(settings, "EMBEDDING_MODEL", "") or "text-embedding-3-small"
        try:
            return _openai_embed(text, openai_key, model), model
        except Exception as exc:  # noqa: BLE001
            logger.warning("OpenAI embedding failed: %s", exc)

    return local_embedding(text), "local-hash-v1"


def refresh_question_embedding(question, *, force: bool = False) -> bool:
    """Soru gövdesi değiştiyse vektörü yenile. Başarısız olsa kayıt bozulmaz."""
    text = embedding_text_for(question)
    digest = text_hash(text)
    if (
        not force
        and question.embedding
        and question.embedding_hash == digest
    ):
        return False
    try:
        vector, model = embed_text(text)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Embedding skipped for %s: %s", question.public_id, exc)
        return False
    question.embedding = vector
    question.embedding_model = model
    question.embedding_hash = digest
    if question.pk:
        question.save(
            update_fields=["embedding", "embedding_model", "embedding_hash"]
        )
    return True


def similar_questions(question, *, limit: int = DEFAULT_LIMIT):
    from .models import Question

    if not question.embedding:
        refresh_question_embedding(question)
    source = list(question.embedding or [])
    if not source:
        return []

    qs = (
        Question.objects.filter(is_published=True, topic__is_active=True)
        .exclude(pk=question.pk)
        .select_related("topic", "topic__subject", "scenario")
    )
    scored: list[tuple[float, object]] = []
    same_subject = question.topic.subject_id if question.topic_id else None
    same_topic = question.topic_id
    for candidate in qs:
        vector = list(candidate.embedding or [])
        if not vector or len(vector) != len(source):
            continue
        score = cosine_similarity(source, vector)
        if same_topic and candidate.topic_id == same_topic:
            score += 0.04
        elif same_subject and candidate.topic.subject_id == same_subject:
            score += 0.02
        if score <= 0:
            continue
        scored.append((score, candidate))
    scored.sort(key=lambda item: item[0], reverse=True)
    return scored[: max(1, min(limit, 20))]


def _openai_embed(text: str, api_key: str, model: str) -> list[float]:
    payload = json.dumps({"model": model, "input": text[:8000]}).encode("utf-8")
    req = urllib.request.Request(
        "https://api.openai.com/v1/embeddings",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        body = json.loads(response.read().decode("utf-8"))
    values = body["data"][0]["embedding"]
    return [float(v) for v in values]


def iter_missing_embeddings(queryset: Iterable) -> list:
    return [q for q in queryset if not q.embedding]
