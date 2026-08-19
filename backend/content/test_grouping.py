"""Konu bazlı otomatik test gruplama (kapasite dolunca Test N+1)."""

from __future__ import annotations

import re
import uuid

from django.db.models import Count

from .models import Question, Topic, TopicTest


def order_questions_keeping_scenarios(
    questions: list[Question],
) -> list[Question]:
    """Grupları bitişik tut: ortak olay sırası, sonra grup içi sıra, sonra id."""
    items = list(questions)
    if not items:
        return []

    def _sort_key(q: Question) -> tuple:
        scenario = getattr(q, "scenario", None)
        if q.scenario_id and scenario is not None:
            return (
                0,
                scenario.sort_order,
                scenario.id,
                q.scenario_order,
                q.id,
            )
        if q.scenario_id:
            return (0, 10**9, q.scenario_id, q.scenario_order, q.id)
        return (1, q.id, 0, 0, q.id)

    return sorted(items, key=_sort_key)


OSYM_PER_TEST = 4
PLAIN_BEFORE_OSYM = 4


def _question_blocks(ordered: list[Question]) -> list[list[Question]]:
    """Aynı olay grubunu tek blokta tut."""
    blocks: list[list[Question]] = []
    index = 0
    while index < len(ordered):
        current = ordered[index]
        if not current.scenario_id:
            blocks.append([current])
            index += 1
            continue
        end = index + 1
        while (
            end < len(ordered)
            and ordered[end].scenario_id == current.scenario_id
        ):
            end += 1
        blocks.append(ordered[index:end])
        index = end
    return blocks


def _is_osym_block(block: list[Question]) -> bool:
    return any(getattr(q, "osym_sordu", False) for q in block)


def _pop_blocks_upto(
    source: list[list[Question]], max_questions: int
) -> list[list[Question]]:
    taken: list[list[Question]] = []
    count = 0
    while source and max_questions > 0:
        nxt = source[0]
        if taken and count + len(nxt) > max_questions:
            break
        if not taken and len(nxt) > max_questions:
            taken.append(source.pop(0))
            break
        taken.append(source.pop(0))
        count += len(taken[-1])
        if count >= max_questions:
            break
    return taken


def interleave_osym_questions(questions: list[Question]) -> list[Question]:
    """Her 4 etiketsiz sorudan sonra 1 ÖSYM; testte en fazla 4 ÖSYM öne alınır.

    Etiketsiz yetmezse kalan sorular normal sırada eklenir. Olay grupları bölünmez.
    """
    if len(questions) < 2:
        return list(questions)
    blocks = _question_blocks(order_questions_keeping_scenarios(questions))
    osym_blocks = [b for b in blocks if _is_osym_block(b)]
    plain_blocks = [b for b in blocks if not _is_osym_block(b)]
    if not osym_blocks or not plain_blocks:
        return [q for b in blocks for q in b]

    osym_use: list[list[Question]] = []
    osym_count = 0
    osym_rest: list[list[Question]] = []
    for block in osym_blocks:
        if osym_count >= OSYM_PER_TEST:
            osym_rest.append(block)
            continue
        osym_use.append(block)
        osym_count += len(block)

    out: list[Question] = []
    plain_i = 0
    osym_i = 0
    plain_since = 0
    while plain_i < len(plain_blocks) or osym_i < len(osym_use):
        if osym_i < len(osym_use) and plain_since >= PLAIN_BEFORE_OSYM:
            out.extend(osym_use[osym_i])
            osym_i += 1
            plain_since = 0
            continue
        if plain_i < len(plain_blocks):
            block = plain_blocks[plain_i]
            plain_i += 1
            out.extend(block)
            plain_since += len(block)
            continue
        break

    for block in osym_use[osym_i:]:
        out.extend(block)
    for block in osym_rest:
        out.extend(block)
    for block in plain_blocks[plain_i:]:
        out.extend(block)
    return out


def chunk_questions_keeping_scenarios(
    ordered: list[Question], capacity: int
) -> list[list[Question]]:
    """Kapasiteye bölerken aynı olay grubunu ayırma."""
    cap = max(1, int(capacity))
    chunks: list[list[Question]] = []
    bucket: list[Question] = []
    for block in _question_blocks(ordered):
        if bucket and len(bucket) + len(block) > cap:
            chunks.append(bucket)
            bucket = []
        if not bucket and len(block) > cap:
            chunks.append(list(block))
            continue
        bucket.extend(block)
    if bucket:
        chunks.append(bucket)
    return chunks


def chunk_questions_with_osym_quota(
    ordered: list[Question], capacity: int
) -> list[list[Question]]:
    """Her teste mümkünse 4 ÖSYM koyar, sonra 4+1 sıraya dizer."""
    cap = max(1, int(capacity))
    osym_blocks = [
        b for b in _question_blocks(ordered) if _is_osym_block(b)
    ]
    plain_blocks = [
        b for b in _question_blocks(ordered) if not _is_osym_block(b)
    ]
    chunks: list[list[Question]] = []
    while osym_blocks or plain_blocks:
        osym_take = _pop_blocks_upto(osym_blocks, OSYM_PER_TEST)
        osym_n = sum(len(b) for b in osym_take)
        plain_take = _pop_blocks_upto(plain_blocks, max(0, cap - osym_n))
        leftover = cap - osym_n - sum(len(b) for b in plain_take)
        if leftover > 0 and osym_blocks:
            osym_take.extend(_pop_blocks_upto(osym_blocks, leftover))
        mixed = [q for b in (plain_take + osym_take) for q in b]
        if not mixed:
            break
        chunks.append(interleave_osym_questions(mixed))
    return chunks

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
    raw = (assignment or "auto").strip().lower()
    if question.scenario_id and raw in ("", "auto"):
        sibling = (
            topic.tests.filter(questions__scenario_id=question.scenario_id)
            .order_by("created_at", "id")
            .first()
        )
        if sibling is not None:
            test = sibling
        else:
            test, _ = resolve_target_test(topic, assignment)
    else:
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
    collected: list[Question] = []
    for t in tests_ordered:
        for q in t.questions.select_related("scenario").order_by("id"):
            if q.pk not in seen:
                seen.add(q.pk)
                collected.append(q)

    # Testte olmayan yayınlı sorular da dahil
    for q in topic.questions.filter(is_published=True).select_related(
        "scenario"
    ).order_by("id"):
        if q.pk not in seen:
            seen.add(q.pk)
            collected.append(q)

    ordered = order_questions_keeping_scenarios(collected)

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

    chunks = chunk_questions_with_osym_quota(ordered, capacity)

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
