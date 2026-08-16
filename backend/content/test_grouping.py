"""Konu bazlı otomatik test gruplama (kapasite dolunca Test N+1)."""

from __future__ import annotations

import re
import uuid

from django.db.models import Count

from .models import Question, Topic, TopicTest

_TEST_NUM = re.compile(r"^\s*Test\s+(\d+)\s*$", re.IGNORECASE)


def _pid(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:10]}"


def topic_test_capacity(topic: Topic) -> int:
    return max(1, int(topic.questions_per_test or 20))


def next_test_number(topic: Topic) -> int:
    """Mevcut 'Test N' başlıklarından sonraki numara."""
    max_n = 0
    for title in topic.tests.values_list("title", flat=True):
        m = _TEST_NUM.match(title or "")
        if m:
            max_n = max(max_n, int(m.group(1)))
    if max_n:
        return max_n + 1
    return topic.tests.count() + 1


def create_topic_test(topic: Topic, *, force_number: int | None = None) -> TopicTest:
    n = force_number if force_number is not None else next_test_number(topic)
    return TopicTest.objects.create(
        topic=topic,
        public_id=_pid("test"),
        title=f"Test {n}",
        time_limit_minutes=topic.time_limit_minutes or 0,
        is_published=True,
    )


def get_open_or_create_test(topic: Topic) -> tuple[TopicTest, bool]:
    """
    Son teste yer varsa onu döndür; yoksa yeni Test N oluştur.
    Dönüş: (test, created)
    """
    capacity = topic_test_capacity(topic)
    last = (
        topic.tests.annotate(qcount=Count("questions"))
        .order_by("-created_at", "-id")
        .first()
    )
    if last is not None and last.qcount < capacity:
        return last, False
    return create_topic_test(topic), True


def resolve_target_test(
    topic: Topic, assignment: str
) -> tuple[TopicTest, bool]:
    """
    assignment:
      - 'auto' / '' → açık test veya yeni
      - 'new' → zorla yeni test
      - '<id>' → mevcut test
    """
    raw = (assignment or "auto").strip().lower()
    if raw in ("", "auto"):
        return get_open_or_create_test(topic)
    if raw == "new":
        return create_topic_test(topic), True
    test = TopicTest.objects.filter(pk=int(raw), topic=topic).first()
    if test is None:
        return get_open_or_create_test(topic)
    return test, False


def assign_question_to_test(
    question: Question,
    topic: Topic,
    assignment: str = "auto",
) -> TopicTest:
    """Soruyu konunun testlerinden birine bağla (önce diğerlerinden çıkar)."""
    if question.topic_id != topic.id:
        question.topic = topic
        question.save(update_fields=["topic", "updated_at"])
    test, _ = resolve_target_test(topic, assignment)
    # Başka konuya ait soruları testten temizle (eski hatalı kayıtlar)
    for other in topic.tests.prefetch_related("questions").all():
        for foreign in [
            q for q in other.questions.all() if q.topic_id != topic.id
        ]:
            other.questions.remove(foreign)
    # Aynı konudaki diğer testlerden çıkar
    for other in topic.tests.filter(questions=question).exclude(pk=test.pk):
        other.questions.remove(question)
    test.questions.add(question)
    return test


def detach_foreign_test_questions(topic: Topic | None = None) -> int:
    """Test–soru bağlarında konu uyumsuzluklarını kaldır."""
    qs = TopicTest.objects.prefetch_related("questions")
    if topic is not None:
        qs = qs.filter(topic=topic)
    removed = 0
    for test in qs:
        for q in test.questions.all():
            if q.topic_id != test.topic_id:
                test.questions.remove(q)
                removed += 1
    return removed


def tests_for_dropdown(topic: Topic, *, selected_test_id: int | None = None):
    """Şablon / partial için test listesi + kapasite bilgisi."""
    capacity = topic_test_capacity(topic)
    rows = []
    for t in (
        topic.tests.annotate(qcount=Count("questions"))
        .order_by("created_at", "id")
    ):
        rows.append(
            {
                "id": t.id,
                "title": t.title,
                "count": t.qcount,
                "capacity": capacity,
                "full": t.qcount >= capacity,
                "selected": selected_test_id == t.id,
            }
        )
    last = (
        topic.tests.annotate(qcount=Count("questions"))
        .order_by("-created_at", "-id")
        .first()
    )
    if last is not None and last.qcount < capacity:
        auto_label = f"Otomatik — {last.title} ({last.qcount}/{capacity})"
    else:
        n = next_test_number(topic)
        auto_label = f"Otomatik — yeni Test {n} (0/{capacity})"
    return {
        "capacity": capacity,
        "auto_label": auto_label,
        "tests": rows,
        "selected_test_id": selected_test_id,
    }


def rebalance_topic_tests(topic: Topic) -> dict:
    """
    Konu kapasitesine göre tüm test sorularını yeniden dağıt.
    Azaltınca fazlalık sonraki teste; artırınca önceki testler dolar.
    Soru public_id değişmez (favoriler bozulmaz).
    """
    capacity = topic_test_capacity(topic)
    tests_ordered = list(topic.tests.order_by("created_at", "id"))

    seen: set[int] = set()
    ordered: list[Question] = []
    for t in tests_ordered:
        for q in t.questions.order_by("id"):
            if q.pk not in seen:
                seen.add(q.pk)
                ordered.append(q)

    # Testte olmayan yayınlı sorular da dahil
    for q in topic.questions.filter(is_published=True).order_by("id"):
        if q.pk not in seen:
            seen.add(q.pk)
            ordered.append(q)

    for t in tests_ordered:
        t.questions.clear()

    if not ordered:
        topic.tests.all().delete()
        return {
            "capacity": capacity,
            "tests": 0,
            "questions": 0,
            "created": 0,
            "removed": len(tests_ordered),
        }

    chunks: list[list[Question]] = [
        ordered[i : i + capacity] for i in range(0, len(ordered), capacity)
    ]

    kept: list[TopicTest] = []
    created = 0
    for i, chunk in enumerate(chunks):
        title = f"Test {i + 1}"
        if i < len(tests_ordered):
            test = tests_ordered[i]
            if test.title != title or not test.is_published:
                test.title = title
                test.is_published = True
                test.save(update_fields=["title", "is_published", "updated_at"])
        else:
            test = create_topic_test(topic, force_number=i + 1)
            created += 1
        test.questions.set(chunk)
        kept.append(test)

    removed = 0
    for t in tests_ordered[len(kept) :]:
        t.delete()
        removed += 1

    return {
        "capacity": capacity,
        "tests": len(kept),
        "questions": len(ordered),
        "created": created,
        "removed": removed,
    }
