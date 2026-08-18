from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import IntegrityError, models, transaction


class Subject(models.Model):
    """Ders (Türkçe, Matematik, …)."""

    slug = models.SlugField(unique=True, max_length=64)
    name = models.CharField(max_length=120)
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name = "Ders"
        verbose_name_plural = "Dersler"

    def __str__(self) -> str:
        return self.name


class Topic(models.Model):
    """Konu — ders altında."""

    subject = models.ForeignKey(
        Subject, on_delete=models.CASCADE, related_name="topics"
    )
    slug = models.SlugField(max_length=64)
    name = models.CharField(max_length=160)
    subtopics = models.JSONField(
        default=list,
        blank=True,
        help_text='Alt konular listesi, örn. ["Sözcükte Anlam", "Cümlede Anlam"]',
    )
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    questions_per_test = models.PositiveIntegerField(default=20)
    time_limit_minutes = models.PositiveIntegerField(
        default=0, help_text="0 = süresiz"
    )
    shuffle_questions = models.BooleanField(default=True)
    shuffle_options = models.BooleanField(default=True)
    show_solution_after_each = models.BooleanField(default=False)

    class Meta:
        ordering = ["sort_order", "name"]
        unique_together = [("subject", "slug")]
        verbose_name = "Konu"
        verbose_name_plural = "Konular"

    def __str__(self) -> str:
        return f"{self.subject.name} · {self.name}"


from .map_catalog import map_template_choices


class MapTemplate(models.Model):
    """Panelden yüklenen özel harita şablonu."""

    KIND_MARKER = "marker"
    KIND_STATIC = "static"
    KIND_CHOICES = [
        (KIND_MARKER, "Koordinatlı işaret"),
        (KIND_STATIC, "Tematik harita"),
    ]

    slug = models.SlugField(unique=True, max_length=64)
    title = models.CharField(max_length=160)
    kind = models.CharField(max_length=16, choices=KIND_CHOICES, default=KIND_STATIC)
    description = models.CharField(max_length=255, blank=True)
    image = models.ImageField(upload_to="maps/")
    editor_image = models.ImageField(
        upload_to="maps/editor/",
        blank=True,
        null=True,
        help_text="Koordinatlı düzenleyici görseli; boşsa ana görsel kullanılır.",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["title"]
        verbose_name = "Harita şablonu"
        verbose_name_plural = "Harita şablonları"

    def __str__(self) -> str:
        return self.title


class QuestionScenario(models.Model):
    """Sözel mantıkta birden çok sorunun paylaştığı ortak olay metni."""

    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="question_scenarios"
    )
    title = models.CharField(max_length=200, verbose_name="Grup başlığı")
    stem = models.TextField(verbose_name="Ortak olay metni")
    sort_order = models.PositiveIntegerField(default=0)
    is_published = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sort_order", "id"]
        verbose_name = "Sözel mantık grubu"
        verbose_name_plural = "Sözel mantık grupları"

    def __str__(self) -> str:
        return f"{self.topic.name} · {self.title}"


class Question(models.Model):
    """Soru bankası kaydı — metin, şıklar, görsel."""

    DIFFICULTY_EASY = "easy"
    DIFFICULTY_MEDIUM = "medium"
    DIFFICULTY_HARD = "hard"
    DIFFICULTY_CHOICES = [
        (DIFFICULTY_EASY, "Kolay"),
        (DIFFICULTY_MEDIUM, "Orta"),
        (DIFFICULTY_HARD, "Zor"),
    ]
    DIFFICULTY_MIN_ATTEMPTS = 1000

    public_id = models.CharField(
        max_length=64,
        unique=True,
        help_text="Mobil senkron için sabit kimlik (örn. q_tr_1)",
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="questions"
    )
    scenario = models.ForeignKey(
        QuestionScenario,
        on_delete=models.SET_NULL,
        related_name="questions",
        blank=True,
        null=True,
        help_text="Sözel mantıkta ortak olay metnini paylaşan soru grubu.",
    )
    scenario_order = models.PositiveIntegerField(
        default=0,
        help_text="Bağlı sorunun grup içindeki sabit sırası.",
    )
    subtopic = models.CharField(max_length=160, blank=True)
    stem = models.TextField(verbose_name="Soru metni")
    image = models.ImageField(
        upload_to="questions/%Y/%m/", blank=True, null=True
    )
    figure_svg = models.TextField(
        blank=True,
        verbose_name="Şekil kodu (SVG)",
        help_text="Geometri soruları için SVG çizim kodu.",
    )
    map_template = models.CharField(
        max_length=64,
        blank=True,
        choices=map_template_choices,
        default="",
        help_text="Koordinatlı harita sorusu şablonu.",
    )
    map_markers = models.JSONField(
        default=list,
        blank=True,
        help_text="Yüzde koordinatlı harita işaretleri.",
    )
    option_a = models.CharField(max_length=500)
    option_b = models.CharField(max_length=500)
    option_c = models.CharField(max_length=500)
    option_d = models.CharField(max_length=500)
    option_e = models.CharField(max_length=500)
    correct_option = models.CharField(
        max_length=1,
        choices=[(c, c) for c in "ABCDE"],
        default="A",
    )
    solution = models.TextField(blank=True, verbose_name="Çözüm")
    is_published = models.BooleanField(default=False)
    difficulty = models.CharField(
        max_length=12,
        choices=DIFFICULTY_CHOICES,
        default=DIFFICULTY_MEDIUM,
        db_index=True,
        verbose_name="Zorluk",
    )
    attempt_count = models.PositiveIntegerField(default=0, editable=False)
    correct_count = models.PositiveIntegerField(default=0, editable=False)
    wrong_count = models.PositiveIntegerField(default=0, editable=False)
    blank_count = models.PositiveIntegerField(default=0, editable=False)
    option_a_count = models.PositiveIntegerField(default=0, editable=False)
    option_b_count = models.PositiveIntegerField(default=0, editable=False)
    option_c_count = models.PositiveIntegerField(default=0, editable=False)
    option_d_count = models.PositiveIntegerField(default=0, editable=False)
    option_e_count = models.PositiveIntegerField(default=0, editable=False)
    osym_sordu = models.BooleanField(
        default=False,
        verbose_name="ÖSYM sordu",
        help_text="İşaretlenirse uygulamada sorunun sağ üstünde ÖSYM rozeti görünür.",
    )
    content_hash = models.CharField(
        max_length=64,
        blank=True,
        default="",
        db_index=True,
        help_text="Normalize soru+şık SHA256 — tekrar yükleme kontrolü",
    )
    stem_hash = models.CharField(
        max_length=64,
        blank=True,
        default="",
        db_index=True,
        help_text="Normalize soru metni SHA256",
    )
    source_image_hash = models.CharField(
        max_length=64,
        blank=True,
        default="",
        db_index=True,
        help_text="OCR kaynağı görsel SHA256 (görsel saklanmasa da)",
    )
    source_image_phash = models.CharField(
        max_length=16,
        blank=True,
        default="",
        db_index=True,
        help_text="Perceptual hash (16 hex) — düzenlenmiş görselleri de yakalar",
    )
    embedding = models.JSONField(
        default=list,
        blank=True,
        help_text="Soru metninin vektör gömülmesi (anlamsal benzerlik).",
    )
    embedding_model = models.CharField(max_length=80, blank=True, default="")
    embedding_hash = models.CharField(
        max_length=64,
        blank=True,
        default="",
        db_index=True,
        help_text="Gömme üretildiğindeki metin parmak izi.",
    )
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Son güncelleme")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Eklenme")

    class Meta:
        ordering = ["-updated_at"]
        indexes = [
            models.Index(
                fields=["topic", "difficulty", "is_published"],
                name="question_topic_difficulty_idx",
            ),
            models.Index(
                fields=["scenario", "scenario_order"],
                name="question_scenario_order_idx",
            ),
        ]
        verbose_name = "Soru"
        verbose_name_plural = "Sorular"

    def __str__(self) -> str:
        return f"{self.public_id} — {self.stem[:48]}"

    def options_map(self) -> dict[str, str]:
        return {
            "A": self.option_a,
            "B": self.option_b,
            "C": self.option_c,
            "D": self.option_d,
            "E": self.option_e,
        }

    def save(self, *args, **kwargs):
        from .question_fingerprint import apply_fingerprints

        apply_fingerprints(self)
        super().save(*args, **kwargs)

    def clean(self):
        super().clean()
        from .map_question_renderer import validate_map_markers

        self.map_markers = validate_map_markers(
            self.map_template,
            self.map_markers,
        )

    @property
    def correct_rate(self) -> float | None:
        if not self.attempt_count:
            return None
        return self.correct_count / self.attempt_count

    @property
    def correct_percentage(self) -> float | None:
        rate = self.correct_rate
        return round(rate * 100, 1) if rate is not None else None

    @property
    def difficulty_visible(self) -> bool:
        return self.attempt_count >= self.DIFFICULTY_MIN_ATTEMPTS


class QuestionAttempt(models.Model):
    """Bir adayın soruya verdiği ilk tamamlanmış cevap."""

    OUTCOME_CORRECT = "correct"
    OUTCOME_WRONG = "wrong"
    OUTCOME_BLANK = "blank"
    OUTCOME_CHOICES = [
        (OUTCOME_CORRECT, "Doğru"),
        (OUTCOME_WRONG, "Yanlış"),
        (OUTCOME_BLANK, "Boş"),
    ]

    question = models.ForeignKey(
        Question, on_delete=models.CASCADE, related_name="attempts"
    )
    user = models.ForeignKey(
        "AppUser", on_delete=models.CASCADE, related_name="question_attempts"
    )
    outcome = models.CharField(max_length=8, choices=OUTCOME_CHOICES)
    selected_option = models.CharField(
        max_length=1,
        choices=[(choice, choice) for choice in "ABCDE"],
        blank=True,
        default="",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["question", "user"],
                name="unique_question_attempt_per_user",
            ),
        ]
        indexes = [
            models.Index(fields=["question", "outcome"], name="attempt_outcome_idx"),
        ]

    @classmethod
    def record_first_answer(
        cls,
        *,
        question: Question,
        user,
        outcome: str,
        selected_option: str = "",
    ) -> bool:
        """Record once per user/question and update its aggregate counters."""
        if outcome not in {
            cls.OUTCOME_CORRECT,
            cls.OUTCOME_WRONG,
            cls.OUTCOME_BLANK,
        }:
            raise ValueError("Geçersiz cevap sonucu.")
        selected_option = selected_option.strip().upper()
        if selected_option not in {"", "A", "B", "C", "D", "E"}:
            raise ValueError("Geçersiz şık.")
        if outcome == cls.OUTCOME_BLANK and selected_option:
            raise ValueError("Boş cevap için şık gönderilemez.")
        if outcome != cls.OUTCOME_BLANK and not selected_option:
            raise ValueError("Cevap sonucu için şık gerekli.")

        with transaction.atomic():
            locked_question = Question.objects.select_for_update().get(pk=question.pk)
            try:
                cls.objects.create(
                    question=locked_question,
                    user=user,
                    outcome=outcome,
                    selected_option=selected_option,
                )
            except IntegrityError:
                return False

            locked_question.attempt_count += 1
            if outcome == cls.OUTCOME_CORRECT:
                locked_question.correct_count += 1
            elif outcome == cls.OUTCOME_WRONG:
                locked_question.wrong_count += 1
            else:
                locked_question.blank_count += 1
            if selected_option:
                option_field = f"option_{selected_option.lower()}_count"
                setattr(
                    locked_question,
                    option_field,
                    getattr(locked_question, option_field) + 1,
                )

            if locked_question.difficulty_visible:
                correct_rate = locked_question.correct_count / locked_question.attempt_count
                non_correct_rate = (
                    locked_question.wrong_count + locked_question.blank_count
                ) / locked_question.attempt_count
                if correct_rate >= 0.80:
                    locked_question.difficulty = Question.DIFFICULTY_EASY
                elif non_correct_rate >= 0.70:
                    locked_question.difficulty = Question.DIFFICULTY_HARD
                else:
                    locked_question.difficulty = Question.DIFFICULTY_MEDIUM

            locked_question.save(
                update_fields=[
                    "attempt_count",
                    "correct_count",
                    "wrong_count",
                    "blank_count",
                    "option_a_count",
                    "option_b_count",
                    "option_c_count",
                    "option_d_count",
                    "option_e_count",
                    "difficulty",
                    "updated_at",
                ]
            )
        return True


class TopicTest(models.Model):
    """Konuya bağlı yayınlanmış test paketi."""

    public_id = models.CharField(max_length=64, unique=True)
    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="tests"
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    time_limit_minutes = models.PositiveIntegerField(default=0)
    questions = models.ManyToManyField(
        Question, related_name="tests", blank=True
    )
    is_published = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Konu testi"
        verbose_name_plural = "Konu testleri"

    def __str__(self) -> str:
        return self.title

    @property
    def question_count(self) -> int:
        return self.questions.filter(
            topic_id=self.topic_id,
            is_published=True,
        ).count()


class TopicLesson(models.Model):
    """Konuya bağlı bilgi / mikro öğrenme kartı."""

    public_id = models.CharField(max_length=64, unique=True)
    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="lessons"
    )
    title = models.CharField(max_length=200)
    body = models.TextField(verbose_name="İçerik")
    image = models.ImageField(
        upload_to="lessons/%Y/%m/", blank=True, null=True
    )
    sort_order = models.PositiveIntegerField(default=0)
    is_published = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sort_order", "id"]
        verbose_name = "Bilgi kartı"
        verbose_name_plural = "Bilgi kartları"

    def __str__(self) -> str:
        return f"{self.topic.name} · {self.title}"


class Announcement(models.Model):
    """Uygulama duyurusu — panelden yönetilir, FCM ile cihaza gider."""

    title = models.CharField(max_length=160, verbose_name="Başlık")
    body = models.TextField(blank=True, verbose_name="Metin")
    image = models.ImageField(
        upload_to="announcements/%Y/%m/",
        blank=True,
        null=True,
        verbose_name="Fotoğraf",
    )
    is_published = models.BooleanField(default=True, verbose_name="Yayında")
    push_sent_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Bildirim gönderildi"
    )
    push_success_count = models.PositiveIntegerField(default=0)
    push_fail_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Duyuru"
        verbose_name_plural = "Duyurular"

    def __str__(self) -> str:
        return self.title


class DeviceToken(models.Model):
    """Mobil FCM cihaz jetonu (Play Store bildirimleri)."""

    user = models.ForeignKey(
        "AppUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="devices",
        verbose_name="Kullanıcı",
    )
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(
        max_length=20,
        default="android",
        choices=[
            ("android", "Android"),
            ("ios", "iOS"),
            ("other", "Diğer"),
        ],
    )
    app_version = models.CharField(max_length=32, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-last_seen_at"]
        verbose_name = "Cihaz jetonu"
        verbose_name_plural = "Cihaz jetonları"

    def __str__(self) -> str:
        return f"{self.platform} · {self.token[:18]}…"


class ContentRevision(models.Model):
    """Tek satırlık içerik sürümü — mobil sync için."""

    version = models.PositiveBigIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "İçerik sürümü"
        verbose_name_plural = "İçerik sürümü"

    def __str__(self) -> str:
        return f"v{self.version}"


class MobileUiConfig(models.Model):
    """Tek satırlık mobil arayüz ayarları — ana sayfa promosyon balonu vb."""

    wrong_notebook_bubble_enabled = models.BooleanField(
        default=True,
        verbose_name="Yanlış defteri balonu aktif",
    )
    wrong_notebook_bubble_label = models.CharField(
        max_length=48,
        default="YANLIŞLARINI GÖR",
        verbose_name="Balon metni",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Mobil arayüz"
        verbose_name_plural = "Mobil arayüz"

    def __str__(self) -> str:
        state = "açık" if self.wrong_notebook_bubble_enabled else "kapalı"
        return f"Mobil arayüz · yanlış balonu {state}"


def get_mobile_ui_config() -> MobileUiConfig:
    obj, _ = MobileUiConfig.objects.get_or_create(pk=1)
    return obj


class AppUser(models.Model):
    """Mobil uygulama kullanıcısı — Google / Play Store hesabı."""

    google_sub = models.CharField(
        max_length=128,
        unique=True,
        verbose_name="Google kimlik",
    )
    email = models.EmailField(db_index=True, verbose_name="E-posta")
    display_name = models.CharField(
        max_length=160, blank=True, verbose_name="Ad"
    )
    display_name_changed_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="Son ad değişikliği",
    )
    photo_url = models.URLField(blank=True, max_length=512)
    is_anonymous = models.BooleanField(
        default=False,
        verbose_name="Anonim hesap",
        help_text="Firebase anonim oturum; Google ile bağlanınca kapanır.",
    )
    is_premium = models.BooleanField(default=False, verbose_name="Premium")
    premium_expires_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Premium bitiş"
    )
    premium_granted_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="Ücretsiz premium veriliş",
        help_text="Admin tarafından ücretsiz premium tanımlandığında dolar.",
    )
    premium_grant_note = models.CharField(
        max_length=255,
        blank=True,
        verbose_name="Premium notu",
        help_text="Örn. hediye, kampanya, destek.",
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name="Aktif",
        help_text="Kapalıysa kullanıcı engellenmiştir; giriş yapamaz.",
    )
    block_reason = models.CharField(
        max_length=255,
        blank=True,
        verbose_name="Engel gerekçesi",
    )
    api_token = models.CharField(
        max_length=64, unique=True, db_index=True, verbose_name="API jetonu"
    )
    last_login_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Son giriş"
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Kayıt")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-last_login_at", "-created_at"]
        verbose_name = "Uygulama kullanıcısı"
        verbose_name_plural = "Uygulama kullanıcıları"

    def __str__(self) -> str:
        return self.display_name or self.email

    @property
    def is_blocked(self) -> bool:
        return not self.is_active

    @property
    def premium_active(self) -> bool:
        if not self.is_premium:
            return False
        if self.premium_expires_at is None:
            return True
        from django.utils import timezone

        return self.premium_expires_at > timezone.now()

    def block(self, reason: str = "") -> None:
        from .auth import new_api_token

        self.is_active = False
        self.block_reason = (reason or "").strip()[:255]
        self.api_token = new_api_token()
        self.save(
            update_fields=[
                "is_active",
                "block_reason",
                "api_token",
                "updated_at",
            ]
        )
        self.devices.filter(is_active=True).update(is_active=False)

    def unblock(self) -> None:
        self.is_active = True
        self.block_reason = ""
        self.save(update_fields=["is_active", "block_reason", "updated_at"])

    def grant_free_premium(
        self,
        *,
        expires_at=None,
        note: str = "",
    ) -> None:
        """Admin / panel üzerinden ücretsiz premium."""
        from django.utils import timezone

        self.is_premium = True
        self.premium_granted_at = timezone.now()
        self.premium_expires_at = expires_at
        self.premium_grant_note = (note or "").strip()[:255]
        self.save(
            update_fields=[
                "is_premium",
                "premium_granted_at",
                "premium_expires_at",
                "premium_grant_note",
                "updated_at",
            ]
        )

    def revoke_free_premium(self) -> None:
        """Ücretsiz premium kaldır (Play satın alması backend'de tutulmaz)."""
        self.is_premium = False
        self.premium_expires_at = None
        self.save(
            update_fields=[
                "is_premium",
                "premium_expires_at",
                "updated_at",
            ]
        )


class QuestionRating(models.Model):
    """Bir öğrencinin bir soruya verdiği değiştirilebilir kalite puanı."""

    question = models.ForeignKey(
        Question,
        on_delete=models.CASCADE,
        related_name="ratings",
        verbose_name="Soru",
    )
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name="question_ratings",
        verbose_name="Öğrenci",
    )
    stars = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        verbose_name="Yıldız",
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="İlk puan")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Güncelleme")

    class Meta:
        ordering = ["-updated_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["question", "user"],
                name="unique_question_rating_per_user",
            ),
            models.CheckConstraint(
                condition=models.Q(stars__gte=1, stars__lte=5),
                name="question_rating_stars_between_1_and_5",
            ),
        ]
        indexes = [
            models.Index(
                fields=["question", "stars"],
                name="rating_question_stars_idx",
            ),
        ]
        verbose_name = "Soru puanı"
        verbose_name_plural = "Soru puanları"

    def __str__(self) -> str:
        return f"{self.question.public_id} · {self.user} · {self.stars}★"


ERROR_REPORT_CATEGORY_CHOICES = [
    ("wrong_answer", "Cevap anahtarı yanlış"),
    ("outdated", "Soru güncel değil"),
    ("typo", "Yazım / ifade hatası"),
    ("missing_content", "Eksik görsel / şekil"),
    ("other", "Diğer"),
]

ERROR_REPORT_STATUS_CHOICES = [
    ("open", "İncelenecek"),
    ("reviewed", "İncelendi"),
    ("resolved", "Çözüldü"),
    ("dismissed", "Reddedildi"),
]


class TopicTestCompletion(models.Model):
    """Kalıcı kullanıcının bitirdiği yayınlı konu testi (hata bildirimi kotası)."""

    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name="topic_test_completions",
        verbose_name="Öğrenci",
    )
    topic_test = models.ForeignKey(
        TopicTest,
        on_delete=models.CASCADE,
        related_name="completions",
        verbose_name="Konu testi",
    )
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "topic_test"],
                name="unique_topic_test_completion_per_user",
            ),
        ]
        verbose_name = "Konu testi tamamlama"
        verbose_name_plural = "Konu testi tamamlamaları"

    def __str__(self) -> str:
        return f"{self.user_id} · {self.topic_test_id}"


class QuestionErrorReport(models.Model):
    """Öğrencinin soru hatası bildirimi — admin inceleme havuzu."""

    question = models.ForeignKey(
        Question,
        on_delete=models.CASCADE,
        related_name="error_reports",
        verbose_name="Soru",
    )
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name="question_error_reports",
        verbose_name="Öğrenci",
    )
    category = models.CharField(
        max_length=32,
        choices=ERROR_REPORT_CATEGORY_CHOICES,
        verbose_name="Bildirim türü",
    )
    note = models.TextField(blank=True, verbose_name="Not")
    status = models.CharField(
        max_length=16,
        choices=ERROR_REPORT_STATUS_CHOICES,
        default="open",
        verbose_name="Durum",
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Bildirildi")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Güncelleme")

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["question", "user"],
                name="unique_question_error_report_per_user",
            ),
        ]
        indexes = [
            models.Index(fields=["status", "-created_at"], name="qerr_status_created"),
            models.Index(fields=["question", "status"], name="qerr_question_status"),
        ]
        verbose_name = "Soru hata bildirimi"
        verbose_name_plural = "Soru hata bildirimleri"

    def __str__(self) -> str:
        return f"{self.question.public_id} · {self.get_category_display()} · {self.status}"


class OcrIngestLog(models.Model):
    """Panel OCR ingest kayıtları — parse kalitesi, hata ve eşleşme izleme."""

    STATUS_SUCCESS = "success"
    STATUS_FAILED = "failed"
    STATUS_FALLBACK_SUCCESS = "fallback_success"
    STATUS_CHOICES = [
        (STATUS_SUCCESS, "Success"),
        (STATUS_FAILED, "Failed"),
        (STATUS_FALLBACK_SUCCESS, "Fallback Success"),
    ]

    image_path = models.CharField(max_length=512, blank=True, default="")
    source_image_hash = models.CharField(max_length=64, blank=True, default="", db_index=True)
    source_image_phash = models.CharField(max_length=16, blank=True, default="", db_index=True)
    engine = models.CharField(max_length=64, blank=True, default="", db_index=True)
    used_model = models.CharField(max_length=128, blank=True, default="", db_index=True)
    status = models.CharField(
        max_length=24,
        choices=STATUS_CHOICES,
        default=STATUS_SUCCESS,
        db_index=True,
    )
    topic = models.ForeignKey(
        Topic,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ocr_ingest_logs",
    )
    duplicate_question = models.ForeignKey(
        Question,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ocr_duplicate_logs",
    )
    duplicate_match = models.CharField(max_length=32, blank=True, default="")
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ocr_ingest_logs",
    )
    ok = models.BooleanField(default=False)
    error_message = models.TextField(blank=True, default="")
    raw_response = models.TextField(blank=True, default="")
    stem = models.TextField(blank=True, default="")
    options = models.JSONField(default=dict, blank=True)
    raw_text = models.TextField(blank=True, default="")
    issue_formula_missing = models.BooleanField(default=False)
    issue_char_drift = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["engine", "-created_at"], name="ocrlog_engine_created"),
            models.Index(fields=["ok", "-created_at"], name="ocrlog_ok_created"),
            models.Index(fields=["duplicate_match"], name="ocrlog_dup_match"),
            models.Index(fields=["status", "-created_at"], name="ocrlog_status_created"),
        ]
        verbose_name = "OCR ingest kaydı"
        verbose_name_plural = "OCR ingest kayıtları"

    def __str__(self) -> str:
        state = "ok" if self.ok else "fail"
        return f"{self.engine or 'ocr'} · {state} · {self.created_at:%Y-%m-%d %H:%M}"


class UserMessage(models.Model):
    """Admin'den tek kullanıcıya gönderilen mesaj (uygulama + FCM)."""

    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name="messages",
        verbose_name="Kullanıcı",
    )
    title = models.CharField(max_length=160, verbose_name="Başlık")
    body = models.TextField(verbose_name="Metin")
    is_read = models.BooleanField(default=False, verbose_name="Okundu")
    push_sent_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Bildirim gönderildi"
    )
    push_success_count = models.PositiveIntegerField(default=0)
    push_fail_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Kullanıcı mesajı"
        verbose_name_plural = "Kullanıcı mesajları"

    def __str__(self) -> str:
        return f"{self.user} · {self.title}"


KPSS_TYPE_CHOICES = (
    ("lisans", "Lisans"),
    ("onLisans", "Ön Lisans"),
    ("ortaogretim", "Ortaöğretim"),
)


class DailyMiniExam(models.Model):
    """Takvim günü + KPSS tipi için sabit 20 soruluk ücretsiz deneme."""

    exam_date = models.DateField(verbose_name="Deneme günü")
    kpss_type = models.CharField(
        max_length=20,
        choices=KPSS_TYPE_CHOICES,
        verbose_name="KPSS tipi",
    )
    question_ids = models.JSONField(
        default=list,
        help_text="Yayınlanmış soru public_id listesi (20 adet hedef).",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [("exam_date", "kpss_type")]
        ordering = ["-exam_date", "kpss_type"]
        verbose_name = "Günün mini denemesi"
        verbose_name_plural = "Günün mini denemeleri"

    def __str__(self) -> str:
        return f"{self.exam_date} · {self.kpss_type} ({len(self.question_ids)})"


class DailyMiniExamAttempt(models.Model):
    """Öğrencinin o günkü mini deneme sonucu — liderlik için tek kayıt."""

    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name="daily_mini_attempts",
        verbose_name="Kullanıcı",
    )
    exam_date = models.DateField(verbose_name="Deneme günü")
    kpss_type = models.CharField(
        max_length=20,
        choices=KPSS_TYPE_CHOICES,
        verbose_name="KPSS tipi",
    )
    correct = models.PositiveSmallIntegerField(default=0)
    wrong = models.PositiveSmallIntegerField(default=0)
    blank = models.PositiveSmallIntegerField(default=0)
    total = models.PositiveSmallIntegerField(default=20)
    duration_seconds = models.PositiveIntegerField(default=0)
    wrong_question_ids = models.JSONField(default=list, blank=True)
    answers = models.JSONField(
        default=dict,
        blank=True,
        help_text='{"q_public_id": "A"}',
    )
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [("user", "exam_date", "kpss_type")]
        ordering = ["-correct", "duration_seconds", "completed_at"]
        indexes = [
            models.Index(
                fields=["exam_date", "kpss_type", "-correct"],
                name="dmini_exam_rank_idx",
            ),
        ]
        verbose_name = "Mini deneme sonucu"
        verbose_name_plural = "Mini deneme sonuçları"

    def __str__(self) -> str:
        return f"{self.user_id} · {self.exam_date} · {self.correct}/{self.total}"


EXAM_ICON_CHOICES = (
    ("school", "Okul"),
    ("book", "Kitap"),
    ("stories", "Ders"),
    ("premium", "Akademi"),
    ("event", "Takvim"),
    ("star", "Yıldız"),
    ("balance", "Adalet"),
    ("military", "Kamu / kurum"),
)


class ExamType(models.Model):
    """Mobil sayaçta gösterilen sınav tipi — panelden eklenir / tarihi güncellenir."""

    slug = models.SlugField(
        unique=True,
        max_length=64,
        help_text="Uygulama kimliği. Örn. kpssLisans, ags, ales. Değiştirme.",
    )
    name = models.CharField(max_length=80, verbose_name="Sınav adı")
    short_name = models.CharField(max_length=40, blank=True, verbose_name="Kısa ad")
    description = models.CharField(
        max_length=160,
        blank=True,
        verbose_name="Açıklama",
    )
    exam_date = models.DateField(verbose_name="Sınav tarihi")
    yearly_repeat = models.BooleanField(
        default=True,
        verbose_name="Her yıl tekrarla",
        help_text="Tarih geçtiyse sonraki yılın aynı gününü göster.",
    )
    even_years_only = models.BooleanField(
        default=False,
        verbose_name="Yalnızca çift yıllar",
        help_text="Ön Lisans ve Ortaöğretim KPSS: tek yıllarda sınav olmaz, sayaç 2 yıl atlar.",
    )
    content_type = models.CharField(
        max_length=20,
        choices=KPSS_TYPE_CHOICES,
        default="lisans",
        verbose_name="Soru bankası tipi",
        help_text="Bu sınav için hangi müfredat (Lisans / Ön Lisans / Ortaöğretim) açılsın.",
    )
    icon_key = models.CharField(
        max_length=20,
        choices=EXAM_ICON_CHOICES,
        default="school",
        verbose_name="İkon",
    )
    sort_order = models.PositiveIntegerField(default=0, verbose_name="Sıra")
    is_active = models.BooleanField(default=True, verbose_name="Aktif")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sort_order", "exam_date", "name"]
        verbose_name = "Sınav tipi"
        verbose_name_plural = "Sınav tipleri"

    def __str__(self) -> str:
        return f"{self.name} ({self.exam_date})"

    def to_api(self) -> dict:
        return {
            "id": self.slug,
            "name": self.name,
            "shortName": self.short_name or self.name,
            "description": self.description,
            "examDate": self.exam_date.isoformat(),
            "yearlyRepeat": self.yearly_repeat,
            "evenYearsOnly": self.even_years_only,
            "contentType": self.content_type,
            "iconKey": self.icon_key,
            "sortOrder": self.sort_order,
            "isActive": self.is_active,
        }


class ExamDistributionTemplate(models.Model):
    """Sınav tipine göre ders/konu soru dağılım şablonu — deneme paketi üretiminde kullanılır."""

    exam_type = models.ForeignKey(
        ExamType,
        on_delete=models.CASCADE,
        related_name="distribution_templates",
        verbose_name="Sınav tipi",
    )
    subject = models.ForeignKey(
        Subject,
        on_delete=models.CASCADE,
        related_name="distribution_templates",
        verbose_name="Ders",
    )
    topic = models.ForeignKey(
        Topic,
        on_delete=models.CASCADE,
        related_name="distribution_templates",
        blank=True,
        null=True,
        verbose_name="Konu",
        help_text="Boş bırakılırsa ders toplamı satırıdır.",
    )
    question_count = models.PositiveIntegerField(
        verbose_name="Soru sayısı",
        validators=[MinValueValidator(1), MaxValueValidator(200)],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["exam_type__sort_order", "subject__sort_order", "topic__sort_order"]
        verbose_name = "Deneme dağılım şablonu"
        verbose_name_plural = "Deneme dağılım şablonları"
        constraints = [
            models.UniqueConstraint(
                fields=["exam_type", "subject", "topic"],
                name="unique_exam_distribution_template",
            ),
        ]

    def __str__(self) -> str:
        topic_label = self.topic.name if self.topic_id else "Toplam"
        return f"{self.exam_type.name} · {self.subject.name} · {topic_label} ({self.question_count})"

    def clean(self) -> None:
        from django.core.exceptions import ValidationError

        if self.topic_id and self.topic.subject_id != self.subject_id:
            raise ValidationError({"topic": "Konu seçilen derse ait olmalı."})


class ExamPack(models.Model):
    """Satılabilir deneme paketi — Dersler vitrininde listelenir."""

    PACK_KIND_FULL = "full"
    PACK_KIND_BRANCH = "branch"
    PACK_KIND_CHOICES = [
        (PACK_KIND_FULL, "Tam deneme"),
        (PACK_KIND_BRANCH, "Branş paketi"),
    ]

    public_id = models.CharField(max_length=64, unique=True)
    exam_type = models.ForeignKey(
        ExamType,
        on_delete=models.CASCADE,
        related_name="exam_packs",
        verbose_name="Sınav tipi",
    )
    pack_kind = models.CharField(
        max_length=16,
        choices=PACK_KIND_CHOICES,
        default=PACK_KIND_BRANCH,
        verbose_name="Paket türü",
    )
    subject = models.ForeignKey(
        Subject,
        on_delete=models.CASCADE,
        related_name="exam_packs",
        blank=True,
        null=True,
        verbose_name="Branş dersi",
        help_text="Branş paketlerinde zorunlu; tam denemede boş.",
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    exam_count = models.PositiveIntegerField(
        default=1,
        verbose_name="Deneme sayısı",
        validators=[MinValueValidator(1), MaxValueValidator(50)],
    )
    time_limit_minutes = models.PositiveIntegerField(
        default=130,
        verbose_name="Süre (dk)",
    )
    price_display = models.CharField(
        max_length=32,
        blank=True,
        verbose_name="Vitrin fiyatı",
        help_text="Örn. 149,99 ₺",
    )
    play_product_id = models.CharField(
        max_length=120,
        blank=True,
        verbose_name="Play Store SKU",
    )
    is_published = models.BooleanField(default=False, verbose_name="Yayında")
    sort_order = models.PositiveIntegerField(default=0, verbose_name="Sıra")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sort_order", "title"]
        verbose_name = "Deneme paketi"
        verbose_name_plural = "Deneme paketleri"

    def __str__(self) -> str:
        return self.title

    def clean(self) -> None:
        from django.core.exceptions import ValidationError

        if self.pack_kind == self.PACK_KIND_BRANCH and not self.subject_id:
            raise ValidationError({"subject": "Branş paketinde ders seçilmeli."})
        if self.pack_kind == self.PACK_KIND_FULL and self.subject_id:
            raise ValidationError({"subject": "Tam denemede branş dersi boş olmalı."})

    @property
    def questions_per_exam(self) -> int:
        first = self.exams.order_by("index").first()
        if first is None:
            return 0
        return first.question_count


class ExamPackExam(models.Model):
    """Paket içindeki tekil deneme oturumu."""

    pack = models.ForeignKey(
        ExamPack,
        on_delete=models.CASCADE,
        related_name="exams",
        verbose_name="Paket",
    )
    index = models.PositiveIntegerField(
        verbose_name="Sıra",
        validators=[MinValueValidator(1), MaxValueValidator(50)],
    )
    title = models.CharField(max_length=200)
    questions = models.ManyToManyField(
        Question,
        through="ExamPackExamQuestion",
        related_name="exam_pack_exams",
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["index"]
        verbose_name = "Paket denemesi"
        verbose_name_plural = "Paket denemeleri"
        constraints = [
            models.UniqueConstraint(
                fields=["pack", "index"],
                name="unique_exam_pack_exam_index",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.pack.title} · {self.title}"

    @property
    def question_count(self) -> int:
        return self.question_links.filter(question__is_published=True).count()


class ExamPackExamQuestion(models.Model):
    """Paket denemesindeki sıralı soru ataması."""

    exam = models.ForeignKey(
        ExamPackExam,
        on_delete=models.CASCADE,
        related_name="question_links",
    )
    question = models.ForeignKey(
        Question,
        on_delete=models.CASCADE,
        related_name="exam_pack_links",
    )
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "id"]
        verbose_name = "Paket soru sırası"
        verbose_name_plural = "Paket soru sıraları"
        constraints = [
            models.UniqueConstraint(
                fields=["exam", "question"],
                name="unique_exam_pack_exam_question",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.exam.title} · #{self.sort_order} · {self.question.public_id}"


class PromoCode(models.Model):
    """Admin tanımlı promosyon kodu — premium süresi ve kota."""

    code = models.CharField(
        max_length=32,
        unique=True,
        db_index=True,
        verbose_name="Kod",
        help_text="Büyük/küçük harf duyarsız; kayıtta otomatik büyük harfe çevrilir.",
    )
    title = models.CharField(
        max_length=120,
        blank=True,
        verbose_name="Başlık",
        help_text="Yalnızca admin panelinde görünür.",
    )
    max_redemptions = models.PositiveIntegerField(
        verbose_name="Maksimum kullanım",
        help_text="Bu koddan yararlanabilecek en fazla kişi sayısı.",
    )
    premium_duration_days = models.PositiveIntegerField(
        verbose_name="Premium süresi (gün)",
        help_text="Kodu kullanan her kullanıcıya tanınan premium gün sayısı.",
    )
    valid_from = models.DateTimeField(
        verbose_name="Geçerlilik başlangıcı",
        help_text="Boş bırakılırsa hemen kullanılabilir.",
        null=True,
        blank=True,
    )
    valid_until = models.DateTimeField(
        verbose_name="Geçerlilik bitişi",
        help_text="Bu tarihten sonra kod kullanılamaz.",
    )
    is_active = models.BooleanField(default=True, verbose_name="Aktif")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Oluşturulma")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Promosyon kodu"
        verbose_name_plural = "Promosyon kodları"

    def __str__(self) -> str:
        label = self.title or self.code
        return f"{label} ({self.code})"

    def save(self, *args, **kwargs):
        self.code = normalize_promo_code(self.code)
        super().save(*args, **kwargs)

    @property
    def redemption_count(self) -> int:
        return self.redemptions.count()

    @property
    def remaining_slots(self) -> int:
        return max(0, self.max_redemptions - self.redemption_count)

    def is_within_schedule(self, moment=None) -> bool:
        from django.utils import timezone

        now = moment or timezone.now()
        if not self.is_active:
            return False
        if self.valid_from and now < self.valid_from:
            return False
        if self.valid_until and now > self.valid_until:
            return False
        return True


class PromoCodeRedemption(models.Model):
    """Promosyon kodu kullanım kaydı."""

    promo_code = models.ForeignKey(
        PromoCode,
        on_delete=models.CASCADE,
        related_name="redemptions",
        verbose_name="Promosyon kodu",
    )
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name="promo_redemptions",
        verbose_name="Kullanıcı",
    )
    redeemed_at = models.DateTimeField(auto_now_add=True, verbose_name="Kullanım zamanı")
    premium_expires_at = models.DateTimeField(
        verbose_name="Verilen premium bitişi",
        help_text="Kullanım anında hesaplanan bitiş tarihi.",
    )

    class Meta:
        ordering = ["-redeemed_at"]
        verbose_name = "Promosyon kullanımı"
        verbose_name_plural = "Promosyon kullanımları"
        constraints = [
            models.UniqueConstraint(
                fields=["promo_code", "user"],
                name="unique_promo_redemption_per_user",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.promo_code.code} · {self.user.email}"


def normalize_promo_code(raw: str) -> str:
    return (raw or "").strip().upper().replace(" ", "")[:32]
