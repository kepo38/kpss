"""OCR metninden ders / konu otomatik algılama — yalnızca panelde kayıtlı konular."""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from functools import lru_cache

from .models import Subject, Topic

# Ders slug → içerik ipuçları (yalnızca panelde o ders varsa puanlanır)
_SUBJECT_HINTS: dict[str, list[tuple[str, int]]] = {
    "matematik": [
        (r"\$[^$]+\$", 8),
        (r"\\frac|\\sqrt|\\begin\{array\}", 10),
        (r"\bgeometri", 8),
        (r"(üçgen|ucgen|dörtgen|dortgen|çember|cember|eşkenar|eskenar|hipotenüs|hipotenus)", 7),
        (r"\b(açı|aci|kenar)", 5),
        (r"\b(problem|işlem|islem|denklem|eşitlik|esitlik|kesir|üs|uslu|kök|koklu)", 5),
        (r"\b[xyzab]\s*[=<>]", 6),
        (r"\b\d+\s*[+\-×*/]\s*\d+\b", 4),
    ],
    "tarih": [
        (r"\b(osmanlı|osmanli|padişah|padisah|sultan|ferman|adalet\s*n[âa]me|adaletname)\b", 9),
        (r"\b(atatürk|ataturk|ink[ıi]lap|tbmm|kurtuluş|kurtulus|cumhuriyet|mondros|sevr|lozan)\b", 9),
        (r"\b(antlaşma|antlasma|savaş|savas|fetih|devleti|devlet|yüzyıl|yüzyil)\b", 6),
        (r"\b(tarih|kronoloji|olay|dönem|donem|reform|isyan|ayaklanma)\b", 4),
    ],
    "cografya": [
        (r"\b(coğrafya|cografya|iklim|nüfus|nufus|tarım|tarim|sanayi|bölge|bolge)\b", 8),
        (r"\b(yer\s*şekli|yersekli|akarsu|göl|gol|plato|ova|fay|deprem|harita)\b", 7),
        (r"\b(enlem|boylam|meridyen|paralel|jeopolitik|kıyı|kiyi)\b", 6),
    ],
    "vatandaslik": [
        (r"\b(anayasa|temel\s*hak|yasama|yürütme|yurutme|yargı|yargi|idare\s*hukuku)\b", 9),
        (r"\b(seçim|secim|demokrasi|meclis|bakan|cumhurbaşkan|milletvekili|kanun)\b", 6),
        (r"\b(vatandaşlık|vatandaslik|kamu\s*görev|devlet\s*memuru)\b", 8),
    ],
    "turkce": [
        (r"\b(paragraf|sözcük|sozcuk|anlam|cümle|cumle|dil\s*bilgisi|yazım|yazim)\b", 8),
        (r"\b(noktalama|ses\s*bilgisi|ünsüz|unsuz|ünlü|unlu|fiil|isim|sıfat|sifat)\b", 7),
        (r"\b(anlatım|anlatim|bozukluk|eş\s*anlaml|es\s*anlam|zıt|zit)\b", 6),
        (r"\b(yukarıdaki\s+parç|asagidaki\s+parç|aşağıdaki\s+parç)\b", 5),
    ],
    "guncel": [
        (r"\b(güncel|guncel|202[0-9]|son\s*dönem|son\s*gelişme)\b", 8),
    ],
}

# Konu slug → ek ipuçları (yalnızca panelde o konu varsa uygulanır)
_TOPIC_HINTS: dict[str, list[tuple[str, int]]] = {
    "mat_geometri": [
        (r"(üçgen|ucgen|açı|aci|çember|cember|eşkenar|eskenar|hipotenüs|hipotenus)", 8),
    ],
    "mat_problem": [(r"\b(problem|hız|hiz|karışım|karisim|işçi|isci|yüzde|yuzde)\b", 6)],
    "mat_uslu": [(r"\b(üs|uslu|\^\{|\\^)\b", 6)],
    "mat_koklu": [(r"\b(kök|koklu|\\sqrt)\b", 6)],
    "turkce_paragraf": [(r"\b(paragraf|parça|metin)\b", 8)],
    "turkce_anlam": [(r"\b(sözcük|sozcuk|anlam|eş\s*anlaml|deyim)\b", 7)],
    "tarih_kronoloji": [(r"\b(kronoloji|sırasıyla|sirasyla|hangisi\s+önce)\b", 9)],
    "tarih_padisah_antlasma": [
        (r"\b(padişah|padisah|antlaşma|antlasma|adalet\s*n[âa]me|ferman|sulh)\b", 10),
    ],
    "tarih_inkilaplar": [(r"\b(ink[ıi]lap|devrim|harf|kılık|kilik|teşkilat|teskilat)\b", 9)],
}


def _normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text or "")
    return text.casefold()


def _blob(stem: str, options: dict[str, str], raw_text: str = "") -> str:
    parts = [stem or "", raw_text or ""]
    parts.extend(str(v) for v in (options or {}).values() if v)
    return _normalize("\n".join(parts))


def _score_rules(blob: str, rules: list[tuple[str, int]]) -> int:
    total = 0
    for pattern, weight in rules:
        if re.search(pattern, blob, re.IGNORECASE | re.DOTALL):
            total += weight
    return total


@lru_cache(maxsize=1)
def _panel_subjects() -> tuple[Subject, ...]:
    return tuple(
        Subject.objects.filter(is_active=True).order_by("sort_order", "id")
    )


@lru_cache(maxsize=1)
def _panel_topics() -> tuple[Topic, ...]:
    return tuple(
        Topic.objects.filter(is_active=True, subject__is_active=True)
        .select_related("subject")
        .order_by("subject__sort_order", "sort_order", "id")
    )


def _panel_subject_slugs() -> frozenset[str]:
    return frozenset(subject.slug for subject in _panel_subjects())


def _panel_topic_by_slug(slug: str) -> Topic | None:
    slug = (slug or "").strip().lower()
    if not slug:
        return None
    for topic in _panel_topics():
        if topic.slug == slug:
            return topic
    return None


def _topic_name_bonus(blob: str, topic: Topic) -> int:
    name = _normalize(topic.name)
    if len(name) >= 4 and name in blob:
        return 14
    tokens = [t for t in re.split(r"[\s·\-–—/]+", name) if len(t) >= 4]
    return sum(4 for t in tokens if t in blob)


def _topic_slug_bonus(blob: str, topic: Topic) -> int:
    score = 0
    for part in topic.slug.split("_"):
        part_norm = _normalize(part)
        if len(part_norm) >= 4 and part_norm in blob:
            score += 3
    return score


def _score_topic(blob: str, topic: Topic, *, subject_bonus: int = 0) -> int:
    score = _topic_name_bonus(blob, topic)
    score += _topic_slug_bonus(blob, topic)
    score += _score_rules(blob, _TOPIC_HINTS.get(topic.slug, []))
    score += subject_bonus
    for sub in topic.subtopics or []:
        sub_norm = _normalize(str(sub))
        if len(sub_norm) >= 5 and sub_norm in blob:
            score += 6
    return score


def _score_panel_subjects(blob: str, *, subject_slug_hint: str = "") -> dict[str, int]:
    scores: dict[str, int] = {}
    for subject in _panel_subjects():
        slug = subject.slug
        total = _score_rules(blob, _SUBJECT_HINTS.get(slug, []))
        subject_name = _normalize(subject.name)
        if len(subject_name) >= 3 and subject_name in blob:
            total += 12
        scores[slug] = total

    hint = (subject_slug_hint or "").strip().lower()
    if hint and hint in _panel_subject_slugs():
        scores[hint] = scores.get(hint, 0) + 25
    return scores


def _best_panel_topic_in_subject(subject_slug: str) -> Topic | None:
    for topic in _panel_topics():
        if topic.subject.slug == subject_slug:
            return topic
    return None


def _rank_panel_topics(
    blob: str,
    *,
    subject_slug_hint: str = "",
    subject_scores: dict[str, int] | None = None,
) -> list[tuple[Topic, int]]:
    scores = subject_scores or _score_panel_subjects(blob, subject_slug_hint=subject_slug_hint)
    if not scores:
        return []

    best_subject = max(scores, key=scores.get)
    best_subject_score = scores[best_subject]
    hint = (subject_slug_hint or "").strip().lower()

    ranked: list[tuple[Topic, int]] = []
    for topic in _panel_topics():
        if hint and hint in _panel_subject_slugs():
            if topic.subject.slug != hint:
                continue
        elif (
            topic.subject.slug != best_subject
            and scores.get(topic.subject.slug, 0) < best_subject_score - 3
        ):
            continue
        subject_bonus = scores.get(topic.subject.slug, 0) // 2
        score = _score_topic(blob, topic, subject_bonus=subject_bonus)
        if score > 0:
            ranked.append((topic, score))
    ranked.sort(key=lambda item: item[1], reverse=True)
    return ranked


def panel_topic_catalog_text(*, max_lines: int = 200) -> str:
    """Gemini prompt'u için paneldeki ders/konu listesi."""
    lines: list[str] = []
    for topic in _panel_topics():
        lines.append(
            f"- ders_slug={topic.subject.slug} "
            f"konu_slug={topic.slug} "
            f"ad={topic.name!r}"
        )
        if len(lines) >= max_lines:
            lines.append("- ...")
            break
    return "\n".join(lines)


@dataclass(frozen=True)
class TopicClassification:
    topic: Topic
    confidence: float
    source: str  # panel_slug | panel_keywords | panel_subject_default | fallback


def classify_topic_from_ocr(
    stem: str,
    options: dict[str, str],
    raw_text: str = "",
    *,
    topic_slug_hint: str = "",
    subject_slug_hint: str = "",
    fallback: Topic | None = None,
    min_confidence: float = 0.35,
) -> TopicClassification | None:
    """Yalnızca panelde kayıtlı aktif konulardan seçim yap."""
    if not _panel_topics():
        return (
            TopicClassification(topic=fallback, confidence=0.0, source="fallback")
            if fallback is not None
            else None
        )

    panel_topic = _panel_topic_by_slug(topic_slug_hint)
    if panel_topic is not None:
        return TopicClassification(
            topic=panel_topic, confidence=1.0, source="panel_slug"
        )

    blob = _blob(stem, options, raw_text)
    subject_scores = _score_panel_subjects(blob, subject_slug_hint=subject_slug_hint)
    ranked = _rank_panel_topics(
        blob,
        subject_slug_hint=subject_slug_hint,
        subject_scores=subject_scores,
    )

    if ranked:
        best_topic, best_score = ranked[0]
        best_subject_score = max(subject_scores.values()) if subject_scores else 1
        confidence = min(1.0, best_score / max(best_subject_score + 20, 1))
        if confidence >= min_confidence:
            return TopicClassification(
                topic=best_topic,
                confidence=confidence,
                source="panel_keywords",
            )

    hint = (subject_slug_hint or "").strip().lower()
    if hint and hint in _panel_subject_slugs():
        default_in_subject = _best_panel_topic_in_subject(hint)
        if default_in_subject is not None:
            return TopicClassification(
                topic=default_in_subject,
                confidence=0.45,
                source="panel_subject_default",
            )

    best_subject = max(subject_scores, key=subject_scores.get) if subject_scores else ""
    if best_subject and subject_scores.get(best_subject, 0) > 0:
        default_in_subject = _best_panel_topic_in_subject(best_subject)
        if default_in_subject is not None:
            return TopicClassification(
                topic=default_in_subject,
                confidence=0.4,
                source="panel_subject_default",
            )

    if fallback is not None and _panel_topic_by_slug(fallback.slug):
        return TopicClassification(
            topic=fallback, confidence=0.0, source="fallback"
        )
    first = _panel_topics()[0]
    return TopicClassification(topic=first, confidence=0.0, source="fallback")


def invalidate_topic_cache() -> None:
    _panel_subjects.cache_clear()
    _panel_topics.cache_clear()
