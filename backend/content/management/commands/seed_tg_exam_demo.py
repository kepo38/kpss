"""TG deneme ekranı için demo soru havuzu + yayınlı deneme oluşturur."""

from __future__ import annotations

import uuid
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db.models import Count
from django.utils import timezone

from content.models import Question, Subject, TgExam, Topic
from content.tg_exam.distribution import DEFAULT_TG_EXAM_DISTRIBUTION
from content.tg_exam.generator import TgExamGeneratorError, TgExamGeneratorService


DEMO_PUBLIC_PREFIX = "q_tg_demo_"

# Coğrafya etiketleri dağılım şemasıyla birebir.
GEO_TAG_TARGETS = {
    "Türkiye'nin Fiziki Özellikleri": 7,
    "Ekonomik Coğrafya": 7,
    "Beşeri Coğrafya": 4,
}

# Ders başına hedef (şema toplamı); coğrafya etiketleri ayrıca.
SUBJECT_TARGETS = {
    "turkce": 30,
    "matematik": 30,
    "tarih": 27,
    "cografya": 18,
    "vatandaslik": 9,
    "guncel": 6,
}

OPTION_BANK = {
    "turkce": ("Anlam", "Yapı", "Ses", "Noktalama", "Paragraf"),
    "matematik": ("12", "18", "24", "30", "36"),
    "tarih": ("Osmanlı", "Selçuklu", "Cumhuriyet", "Bizans", "Roma"),
    "cografya": ("Karadeniz", "Akdeniz", "Ege", "İç Anadolu", "Doğu Anadolu"),
    "vatandaslik": ("Yasama", "Yürütme", "Yargı", "Anayasa", "İdare"),
    "guncel": ("2023", "2024", "2025", "2026", "2022"),
}


def _pid() -> str:
    return f"{DEMO_PUBLIC_PREFIX}{uuid.uuid4().hex[:10]}"


class Command(BaseCommand):
    help = (
        "TG deneme için eksik derslerde demo soru üretir, 120 soruluk "
        "yayınlı deneme oluşturur (şu an girilebilir)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="q_tg_demo_* soruları ve demo TG denemelerini sil",
        )
        parser.add_argument(
            "--kpss-type",
            default="lisans",
            help="KPSS tipi (varsayılan: lisans)",
        )

    def handle(self, *args, **options):
        if options["clear"]:
            self._clear()
            return

        kpss_type = options["kpss_type"]
        created = self._ensure_demo_questions()
        self.stdout.write(f"Yeni demo soru: {created}")

        try:
            question_ids = TgExamGeneratorService(
                kpss_type=kpss_type,
                seed=42,
            ).generate()
        except TgExamGeneratorError as exc:
            self.stderr.write(self.style.ERROR(f"Üretim başarısız: {exc}"))
            self._print_pool_stats()
            raise SystemExit(1) from exc

        exam = self._upsert_demo_exam(kpss_type, question_ids)
        self.stdout.write(
            self.style.SUCCESS(
                f"TG deneme hazır: id={exam.pk} · {exam.title} · "
                f"{exam.question_count} soru · yayında={exam.is_published}"
            )
        )
        self.stdout.write(
            f"Pencere: {exam.start_at.isoformat()} → {exam.end_at.isoformat()}"
        )

    def _clear(self) -> None:
        q_deleted, _ = Question.objects.filter(
            public_id__startswith=DEMO_PUBLIC_PREFIX
        ).delete()
        e_deleted, _ = TgExam.objects.filter(
            title__startswith="[DEMO] TG"
        ).delete()
        self.stdout.write(
            self.style.WARNING(
                f"Silindi: {q_deleted} demo soru, {e_deleted} demo deneme"
            )
        )

    def _topic_for_subject(self, subject: Subject) -> Topic:
        topic = (
            subject.topics.filter(is_active=True)
            .order_by("sort_order", "id")
            .first()
        )
        if topic is None:
            topic = Topic.objects.create(
                subject=subject,
                slug=f"{subject.slug}_tg_demo",
                name=f"{subject.name} · TG Demo",
                is_active=True,
                sort_order=999,
            )
        return topic

    def _ensure_demo_questions(self) -> int:
        created = 0
        for slug, target in SUBJECT_TARGETS.items():
            subject = Subject.objects.filter(slug=slug, is_active=True).first()
            if subject is None:
                self.stderr.write(
                    self.style.WARNING(f"Ders yok, atlandı: {slug}")
                )
                continue
            topic = self._topic_for_subject(subject)

            if slug == "cografya":
                created += self._ensure_geo_tagged(subject, topic)
                continue

            have = Question.objects.filter(
                is_published=True,
                topic__subject=subject,
            ).count()
            need = max(0, target - have + 2)  # küçük tampon
            for i in range(need):
                self._create_question(subject, topic, index=i)
                created += 1
        return created

    def _ensure_geo_tagged(self, subject: Subject, topic: Topic) -> int:
        created = 0
        for tag, target in GEO_TAG_TARGETS.items():
            have = Question.objects.filter(
                is_published=True,
                topic__subject=subject,
                subtopic__iexact=tag,
            ).count()
            need = max(0, target - have + 1)
            for i in range(need):
                self._create_question(
                    subject, topic, index=i, subtopic=tag
                )
                created += 1
        # Genel coğrafya tamponu (etiketsiz)
        have_any = Question.objects.filter(
            is_published=True,
            topic__subject=subject,
        ).count()
        if have_any < SUBJECT_TARGETS["cografya"] + 3:
            for i in range(SUBJECT_TARGETS["cografya"] + 3 - have_any):
                self._create_question(subject, topic, index=100 + i)
                created += 1
        return created

    def _create_question(
        self,
        subject: Subject,
        topic: Topic,
        *,
        index: int,
        subtopic: str = "",
    ) -> Question:
        opts = OPTION_BANK.get(subject.slug, OPTION_BANK["guncel"])
        label = subtopic or subject.name
        stem = (
            f"[TG DEMO] {label} — örnek soru {index + 1}. "
            f"Aşağıdakilerden hangisi doğrudur?"
        )
        return Question.objects.create(
            public_id=_pid(),
            topic=topic,
            subtopic=subtopic,
            stem=stem,
            option_a=opts[0],
            option_b=opts[1],
            option_c=opts[2],
            option_d=opts[3],
            option_e=opts[4],
            correct_option="A",
            solution="Demo çözüm — test amaçlı.",
            is_published=True,
            difficulty="easy",
        )

    def _upsert_demo_exam(
        self, kpss_type: str, question_ids: list[str]
    ) -> TgExam:
        now = timezone.now()
        start = now - timedelta(hours=1)
        end = now + timedelta(days=2)
        title = f"[DEMO] TG Deneme · {kpss_type}"

        exam = (
            TgExam.objects.filter(title=title, kpss_type=kpss_type)
            .order_by("-id")
            .first()
        )
        if exam is None:
            exam = TgExam(title=title, kpss_type=kpss_type)

        exam.start_at = start
        exam.end_at = end
        exam.duration_minutes = 130
        exam.question_ids = question_ids
        exam.is_published = True
        exam.is_results_published = False
        exam.results_published_at = None
        exam.save()
        return exam

    def _print_pool_stats(self) -> None:
        rows = (
            Question.objects.filter(is_published=True)
            .values("topic__subject__slug")
            .annotate(c=Count("id"))
            .order_by("topic__subject__slug")
        )
        self.stdout.write("Yayınlı havuz:")
        for row in rows:
            self.stdout.write(f"  {row['topic__subject__slug']}: {row['c']}")
        self.stdout.write(f"Dağılım: {DEFAULT_TG_EXAM_DISTRIBUTION}")
