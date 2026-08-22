"""
Django settings for KPSS Odak content admin.
"""

import os
from pathlib import Path

from django.templatetags.static import static
from django.urls import reverse_lazy
from django.utils.translation import gettext_lazy as _

BASE_DIR = Path(__file__).resolve().parent.parent

# Yerel .env (gitignore) — GEMINI_API_KEY vb.
_env_file = BASE_DIR / ".env"
if _env_file.exists():
    for _line in _env_file.read_text(encoding="utf-8").splitlines():
        _line = _line.strip()
        if not _line or _line.startswith("#") or "=" not in _line:
            continue
        _k, _sep, _v = _line.partition("=")
        _k, _v = _k.strip(), _v.strip().strip('"').strip("'")
        if _k and _k not in os.environ:
            os.environ[_k] = _v

SECRET_KEY = "django-insecure-dev-only-change-in-production"
DEBUG = True
ALLOWED_HOSTS = ["*", "10.0.2.2", "127.0.0.1", "localhost"]

INSTALLED_APPS = [
    "unfold",
    "unfold.contrib.filters",
    "unfold.contrib.forms",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "content.apps.ContentConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "content.panel_context.panel_nav_context",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"
    },
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "tr-tr"
TIME_ZONE = "Europe/Istanbul"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGIN_URL = "/admin/login/"
LOGIN_REDIRECT_URL = "/panel/"

FILE_UPLOAD_MAX_MEMORY_SIZE = 8 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024

# Tesseract OCR (soru görseli → metin)
TESSERACT_CMD = os.environ.get(
    "TESSERACT_CMD",
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
)
TESSDATA_DIR = os.environ.get("TESSDATA_DIR", str(BASE_DIR / "tessdata"))
# Türkçe diyakritik (ğüşıöç) için tur öncelikli; gerekirse tur+eng
TESSERACT_LANG = os.environ.get("TESSERACT_LANG", "tur,tur+eng")
DEFAULT_CHARSET = "utf-8"

# Gemini Vision — matematik OCR fallback (ücretsiz kota: AI Studio)
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_OCR_MODEL = os.environ.get("GEMINI_OCR_MODEL", "gemini-flash-latest")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
EMBEDDING_MODEL = os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")

# Telegram soru botu — fotoğraf → OCR → onay bekleyen soru
# Token / kullanıcı ID: backend/.env.example (TELEGRAM_*)
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_WEBHOOK_SECRET = os.environ.get("TELEGRAM_WEBHOOK_SECRET", "")
TELEGRAM_ALLOWED_USER_IDS = [
    int(part.strip())
    for part in os.environ.get("TELEGRAM_ALLOWED_USER_IDS", "").split(",")
    if part.strip().isdigit()
]
TELEGRAM_DEFAULT_TOPIC_SLUG = os.environ.get(
    "TELEGRAM_DEFAULT_TOPIC_SLUG", "turkce_anlam"
)

CORS_ALLOW_ALL_ORIGINS = True

REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.AllowAny",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "question_rating": "60/min",
        "question_error_report": "30/min",
        "promo_redeem": "5/min",
    },
}

# ── HEDEF Kamu · Unfold (premium admin) ─────────────────────────────
UNFOLD = {
    "SITE_TITLE": "HEDEF Kamu",
    "SITE_HEADER": "HEDEF Kamu",
    "SITE_SUBHEADER": "İçerik yönetim paneli",
    "SITE_URL": "/admin/",
    "SITE_SYMBOL": "H",
    "SHOW_HISTORY": True,
    "SHOW_VIEW_ON_SITE": False,
    "SHOW_BACK_BUTTON": True,
    "THEME": "dark",
    "BORDER_RADIUS": "10px",
    "STYLES": [
        lambda request: static("admin/css/kpss_odak.css"),
    ],
    "COLORS": {
        # Ink navy surfaces
        "base": {
            "50": "oklch(97% 0.005 250)",
            "100": "oklch(94% 0.008 250)",
            "200": "oklch(88% 0.012 250)",
            "300": "oklch(78% 0.02 250)",
            "400": "oklch(62% 0.03 250)",
            "500": "oklch(48% 0.035 250)",
            "600": "oklch(38% 0.04 250)",
            "700": "oklch(28% 0.04 250)",
            "800": "oklch(20% 0.035 250)",
            "900": "oklch(14% 0.03 250)",
            "950": "oklch(10% 0.025 250)",
        },
        # Champagne gold accent (app brand)
        "primary": {
            "50": "oklch(97% 0.02 85)",
            "100": "oklch(93% 0.035 85)",
            "200": "oklch(87% 0.055 85)",
            "300": "oklch(80% 0.08 85)",
            "400": "oklch(76% 0.09 85)",
            "500": "oklch(72% 0.1 85)",
            "600": "oklch(64% 0.1 80)",
            "700": "oklch(54% 0.09 75)",
            "800": "oklch(44% 0.07 70)",
            "900": "oklch(35% 0.05 65)",
            "950": "oklch(24% 0.04 60)",
        },
        "font": {
            "subtle-light": "oklch(55% 0.02 250)",
            "subtle-dark": "oklch(70% 0.02 250)",
            "default-light": "oklch(35% 0.03 250)",
            "default-dark": "oklch(90% 0.01 250)",
            "important-light": "oklch(18% 0.03 250)",
            "important-dark": "oklch(97% 0.005 250)",
        },
    },
    "SIDEBAR": {
        "show_search": True,
        "show_all_applications": False,
        "navigation": [
            {
                "title": _("Genel"),
                "separator": True,
                "items": [
                    {
                        "title": _("Panel"),
                        "icon": "dashboard",
                        "link": reverse_lazy("admin:index"),
                    },
                    {
                        "title": _("İçerik paneli"),
                        "icon": "edit_note",
                        "link": "/panel/",
                    },
                ],
            },
            {
                "title": _("Müfredat"),
                "separator": True,
                "collapsible": True,
                "items": [
                    {
                        "title": _("Dersler"),
                        "icon": "menu_book",
                        "link": reverse_lazy("admin:content_subject_changelist"),
                    },
                    {
                        "title": _("Konular"),
                        "icon": "topic",
                        "link": reverse_lazy("admin:content_topic_changelist"),
                    },
                ],
            },
            {
                "title": _("İçerik"),
                "separator": True,
                "collapsible": True,
                "items": [
                    {
                        "title": _("Sorular"),
                        "icon": "quiz",
                        "link": reverse_lazy("admin:content_question_changelist"),
                    },
                    {
                        "title": _("Konu testleri"),
                        "icon": "assignment",
                        "link": reverse_lazy("admin:content_topictest_changelist"),
                    },
                    {
                        "title": _("Duyurular"),
                        "icon": "campaign",
                        "link": reverse_lazy(
                            "admin:content_announcement_changelist"
                        ),
                    },
                    {
                        "title": _("Panel duyurular"),
                        "icon": "notifications",
                        "link": "/panel/duyuru/",
                    },
                ],
            },
            {
                "title": _("Sistem"),
                "separator": True,
                "collapsible": True,
                "items": [
                    {
                        "title": _("Uygulama kullanıcıları"),
                        "icon": "smartphone",
                        "link": reverse_lazy("admin:content_appuser_changelist"),
                    },
                    {
                        "title": _("Promosyon kodları"),
                        "icon": "redeem",
                        "link": reverse_lazy("admin:content_promocode_changelist"),
                    },
                    {
                        "title": _("Promosyon geçmişi"),
                        "icon": "history",
                        "link": reverse_lazy(
                            "admin:content_promocoderedemption_changelist"
                        ),
                    },
                    {
                        "title": _("Personel"),
                        "icon": "people",
                        "link": reverse_lazy("admin:auth_user_changelist"),
                    },
                    {
                        "title": _("API paket"),
                        "icon": "api",
                        "link": "/api/v1/pack/",
                    },
                ],
            },
        ],
    },
}

# Firebase Cloud Messaging (Play Store bildirimleri)
# Servis hesabı JSON: Firebase Console → Project settings → Service accounts → Generate key
FIREBASE_CREDENTIALS = os.environ.get(
    "FIREBASE_CREDENTIALS",
    str(BASE_DIR / "firebase-service-account.json"),
)
FCM_ANNOUNCEMENT_TOPIC = os.environ.get("FCM_ANNOUNCEMENT_TOPIC", "kpss_duyuru")
FCM_CONTENT_TOPIC = os.environ.get("FCM_CONTENT_TOPIC", "kpss_content")
CONTENT_PUSH_DEBOUNCE_SECONDS = float(
    os.environ.get("CONTENT_PUSH_DEBOUNCE_SECONDS", "2")
)
# FCM görsel bildirimi için cihazın erişebildiği taban URL (LAN veya üretim HTTPS)
PUBLIC_BASE_URL = os.environ.get(
    "PUBLIC_BASE_URL", "http://192.168.1.109:8000"
).rstrip("/")

# Google Sign-In / Firebase Auth — virgülle ayrılmış OAuth client ID listesi
# (Android + Web client). Boş bırakılırsa Google tokeninfo aud kontrolü atlanır.
_google_ids = os.environ.get(
    "GOOGLE_OAUTH_CLIENT_IDS",
    "89822639053-hj0d3dqf5291nepb5evoj6oc8phv5l26.apps.googleusercontent.com,"
    "89822639053-b9icipsq1nogcesdrq0l1b8i142ncb4d.apps.googleusercontent.com",
).strip()
GOOGLE_OAUTH_CLIENT_IDS = [x.strip() for x in _google_ids.split(",") if x.strip()]
