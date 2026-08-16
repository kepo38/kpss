from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


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


class Question(models.Model):
    """Soru bankası kaydı — metin, şıklar, görsel."""

    MAP_TEMPLATE_CHOICES = map_template_choices()

    public_id = models.CharField(
        max_length=64,
        unique=True,
        help_text="Mobil senkron için sabit kimlik (örn. q_tr_1)",
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="questions"
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
        max_length=32,
        blank=True,
        choices=MAP_TEMPLATE_CHOICES,
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
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Son güncelleme")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Eklenme")

    class Meta:
        ordering = ["-updated_at"]
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
    return (raw or "").strip().upper().replace(" ", "")
