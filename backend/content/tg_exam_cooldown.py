"""TG denemelerinde soru tekrarını sınırlama — son N deneme / ay cooldown."""

from __future__ import annotations

from datetime import timedelta

from django.db.models import F
from django.utils import timezone

from .models import Question, TgExam

# Son kaç yayınlanmış TG denemesindeki kolay/orta sorular hariç tutulur.
TG_EXAM_COOLDOWN_EXAM_COUNT = 4

# Ek tarih eşiği — deneme sayısı yetmezse yedek filtre (≈4 ay).
TG_EXAM_COOLDOWN_DAYS = 120

COOLDOWN_DIFFICULTIES = frozenset(
    {Question.DIFFICULTY_EASY, Question.DIFFICULTY_MEDIUM},
)


def recent_tg_exam_question_ids(
    *,
    kpss_type: str,
    exclude_exam_id: int | None = None,
    last_n_exams: int = TG_EXAM_COOLDOWN_EXAM_COUNT,
) -> set[str]:
    """Son N yayınlanmış TG denemesinde kullanılan soru public_id'leri."""
    qs = TgExam.objects.filter(is_published=True, kpss_type=kpss_type)
    if exclude_exam_id:
        qs = qs.exclude(pk=exclude_exam_id)
    recent = qs.order_by("-start_at", "-id")[:last_n_exams]
    ids: set[str] = set()
    for exam in recent:
        ids.update(exam.question_ids or [])
    return ids


def cooldown_excluded_public_ids(
    *,
    kpss_type: str,
    exclude_exam_id: int | None = None,
    last_n_exams: int = TG_EXAM_COOLDOWN_EXAM_COUNT,
) -> set[str]:
    """
    Yeni deneme havuzundan çıkarılacak kolay/orta sorular.

    Hariç tutulur:
    - Son N yayınlanmış TG denemesinde yer almış kolay/orta sorular
    - tg_exam_cooldown_counter < N (henüz 5. deneme döngüsüne girmemiş)
    """
    recent_ids = recent_tg_exam_question_ids(
        kpss_type=kpss_type,
        exclude_exam_id=exclude_exam_id,
        last_n_exams=last_n_exams,
    )

    excluded: set[str] = set()
    if recent_ids:
        excluded.update(
            Question.objects.filter(
                public_id__in=recent_ids,
                difficulty__in=COOLDOWN_DIFFICULTIES,
            ).values_list("public_id", flat=True)
        )

    cutoff = timezone.now() - timedelta(days=TG_EXAM_COOLDOWN_DAYS)
    excluded.update(
        Question.objects.filter(
            difficulty__in=COOLDOWN_DIFFICULTIES,
            last_used_in_tg_exam_at__isnull=False,
            tg_exam_cooldown_counter__lt=last_n_exams,
            last_used_in_tg_exam_at__gte=cutoff,
        ).values_list("public_id", flat=True)
    )
    return excluded


def record_tg_exam_question_usage(exam: TgExam) -> int:
    """
    Deneme yayınlandığında soru kullanım metadatasını güncelle.

    - Denemedeki sorular: last_used_in_tg_exam_at=now, counter=0
    - Daha önce TG'de sorulmuş diğer sorular: counter += 1

    Returns: güncellenen soru sayısı.
    """
    now = timezone.now()
    question_ids = [qid for qid in (exam.question_ids or []) if qid]
    if not question_ids:
        return 0

    used_count = Question.objects.filter(public_id__in=question_ids).update(
        last_used_in_tg_exam_at=now,
        tg_exam_cooldown_counter=0,
    )

    Question.objects.filter(last_used_in_tg_exam_at__isnull=False).exclude(
        public_id__in=question_ids,
    ).update(tg_exam_cooldown_counter=F("tg_exam_cooldown_counter") + 1)

    return used_count


def is_question_on_cooldown(
    question: Question,
    *,
    cooldown_ids: set[str],
    last_n_exams: int = TG_EXAM_COOLDOWN_EXAM_COUNT,
) -> bool:
    """Kolay/orta soru cooldown'da mı? Zor sorular serbest."""
    if question.difficulty not in COOLDOWN_DIFFICULTIES:
        return False
    if question.public_id in cooldown_ids:
        return True
    if (
        question.last_used_in_tg_exam_at is not None
        and question.tg_exam_cooldown_counter < last_n_exams
    ):
        return True
    cutoff = timezone.now() - timedelta(days=TG_EXAM_COOLDOWN_DAYS)
    if (
        question.last_used_in_tg_exam_at is not None
        and question.last_used_in_tg_exam_at >= cutoff
        and question.tg_exam_cooldown_counter < last_n_exams
    ):
        return True
    return False
