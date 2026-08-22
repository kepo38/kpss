"""Telegram bot — soru fotoğrafı → OCR → onay bekleyen soru."""

from __future__ import annotations

import io
import json
import logging
import os
import ssl
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator, Literal

from django.conf import settings

from django.db import IntegrityError

from .models import Question, Topic
from .ocr_ingest import ingest_question_from_image
from .panel_context import pending_telegram_question_count
from .telegram_conversation import (
    ConversationReply,
    clear_session,
    get_session,
    solution_prompt_keyboard,
    solution_prompt_message,
    start_solution_prompt,
    try_handle_conversation,
    try_handle_conversation_callback,
)

logger = logging.getLogger(__name__)

HandleOutcome = Literal[
    "ingested", "skipped", "error", "command", "ignored", "unauthorized"
]

_inflight_lock = threading.Lock()
_inflight_keys: set[str] = set()
_inflight_started: dict[str, float] = {}
_INFLIGHT_TTL_SECONDS = 900

_photo_executor: ThreadPoolExecutor | None = None
_photo_executor_lock = threading.Lock()

_DRAIN_ERROR_LINE = (
    "Hata: {count} (fotoğraflar bot sohbetinde — TELEGRAM.bat'ı tekrar çalıştırın)"
)
_DRAIN_ERROR_FOOTER = (
    "Tekrar çalıştırınca aynı fotoğraflar otomatik yeniden denenecek."
)

_CLEAR_CHAT_COMMANDS = frozenset({
    "/sohbeti_sil",
    "/sohbetisil",
    "/temizle",
    "sohbeti sil",
    "sohbet sil",
    "sohbeti temizle",
})

_MAX_TRACKED_CHAT_MESSAGES = 500
_chat_message_ids: dict[int, list[int]] = {}
_chat_messages_loaded = False
_chat_messages_lock = threading.Lock()


def _chat_messages_path() -> Path:
    return lock_file_path().parent / "telegram_chat_messages.json"


def _load_chat_messages() -> None:
    global _chat_messages_loaded
    if _chat_messages_loaded:
        return
    path = _chat_messages_path()
    if path.exists():
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                for key, value in raw.items():
                    if not isinstance(value, list):
                        continue
                    chat_id = int(key)
                    ids = [
                        int(message_id)
                        for message_id in value
                        if str(message_id).isdigit()
                    ]
                    if ids:
                        _chat_message_ids[chat_id] = ids[-_MAX_TRACKED_CHAT_MESSAGES:]
        except (OSError, ValueError, TypeError):
            logger.warning("Telegram chat message registry okunamadı: %s", path)
    _chat_messages_loaded = True


def _save_chat_messages() -> None:
    path = _chat_messages_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            str(chat_id): message_ids[-_MAX_TRACKED_CHAT_MESSAGES:]
            for chat_id, message_ids in _chat_message_ids.items()
            if message_ids
        }
        path.write_text(
            json.dumps(payload, ensure_ascii=False),
            encoding="utf-8",
        )
    except OSError:
        logger.warning("Telegram chat message registry yazılamadı: %s", path)


def _track_chat_message(chat_id: int, message_id: int) -> None:
    if not message_id:
        return
    with _chat_messages_lock:
        _load_chat_messages()
        ids = _chat_message_ids.setdefault(int(chat_id), [])
        message_id = int(message_id)
        if message_id in ids:
            return
        ids.append(message_id)
        if len(ids) > _MAX_TRACKED_CHAT_MESSAGES:
            del ids[: len(ids) - _MAX_TRACKED_CHAT_MESSAGES]
        _save_chat_messages()


def _untrack_chat_message(chat_id: int, message_id: int) -> None:
    if not message_id:
        return
    with _chat_messages_lock:
        _load_chat_messages()
        ids = _chat_message_ids.get(int(chat_id))
        if not ids:
            return
        try:
            ids.remove(int(message_id))
        except ValueError:
            return
        if not ids:
            _chat_message_ids.pop(int(chat_id), None)
        _save_chat_messages()


def _collect_known_chat_message_ids(chat_id: int) -> list[int]:
    from .models import Question, TelegramBotSession

    extra: set[int] = set()
    for message_id in Question.objects.filter(
        telegram_chat_id=int(chat_id),
        telegram_message_id__isnull=False,
    ).values_list("telegram_message_id", flat=True):
        extra.add(int(message_id))
    for message_id in TelegramBotSession.objects.filter(
        chat_id=int(chat_id),
        source_message_id__isnull=False,
    ).values_list("source_message_id", flat=True):
        extra.add(int(message_id))
    return sorted(extra)


def _try_delete_message(chat_id: int, message_id: int) -> bool:
    if not message_id:
        return False
    try:
        _post(
            "deleteMessage",
            {"chat_id": int(chat_id), "message_id": int(message_id)},
        )
        _untrack_chat_message(int(chat_id), int(message_id))
        return True
    except Exception:
        logger.debug(
            "Telegram deleteMessage skipped chat_id=%s message_id=%s",
            chat_id,
            message_id,
        )
        return False


def _purge_chat_messages(
    chat_id: int,
    *,
    extra_ids: list[int] | None = None,
) -> tuple[int, int]:
    with _chat_messages_lock:
        _load_chat_messages()
        tracked = list(_chat_message_ids.pop(int(chat_id), []))
    candidates = set(tracked)
    if extra_ids:
        candidates.update(int(message_id) for message_id in extra_ids if message_id)
    candidates.update(_collect_known_chat_message_ids(int(chat_id)))

    deleted = 0
    failed = 0
    for message_id in sorted(candidates, reverse=True):
        if _try_delete_message(int(chat_id), int(message_id)):
            deleted += 1
        else:
            failed += 1
        time.sleep(0.04)

    with _chat_messages_lock:
        _chat_message_ids[int(chat_id)] = []
        _save_chat_messages()
    return deleted, failed


def drain_error_summary(count: int) -> str:
    return _DRAIN_ERROR_LINE.format(count=count)


def drain_error_footer() -> str:
    return _DRAIN_ERROR_FOOTER


class TelegramBotLockError(RuntimeError):
    """TELEGRAM.bat / run_telegram_bot zaten calisiyor."""


class PhotoAlreadyProcessing(RuntimeError):
    """Ayni Telegram mesaji baska bir OCR/islemde."""


def lock_file_path() -> Path:
    custom = getattr(settings, "TELEGRAM_LOCK_FILE", "") or ""
    if custom:
        return Path(custom)
    return Path(settings.BASE_DIR).parent / "telegram_bot.lock"


def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def acquire_telegram_lock() -> None:
    path = lock_file_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        try:
            old_pid = int(path.read_text(encoding="utf-8").strip())
        except ValueError:
            old_pid = 0
        if old_pid and _pid_alive(old_pid):
            raise TelegramBotLockError(
                f"Telegram aktarımı zaten çalışıyor (PID {old_pid}). "
                "İkinci TELEGRAM.bat açmayın."
            )
        path.unlink(missing_ok=True)
    path.write_text(str(os.getpid()), encoding="utf-8")


def release_telegram_lock() -> None:
    path = lock_file_path()
    if not path.exists():
        return
    try:
        owner = int(path.read_text(encoding="utf-8").strip())
    except ValueError:
        owner = 0
    if owner in (0, os.getpid()):
        path.unlink(missing_ok=True)


def telegram_lock_active() -> bool:
    path = lock_file_path()
    if not path.exists():
        return False
    try:
        pid = int(path.read_text(encoding="utf-8").strip())
    except ValueError:
        return False
    return _pid_alive(pid)


def _retry_hint() -> str:
    if telegram_lock_active():
        return (
            "TELEGRAM-WATCH açıksa birkaç saniye içinde otomatik yeniden denenecek."
        )
    return "TELEGRAM.bat veya TELEGRAM-WATCH.bat ile tekrar deneyin."


def _processing_key(chat_id: int, message_id: int) -> str:
    return f"{chat_id}:{message_id}"


def _prune_stale_inflight() -> None:
    now = time.monotonic()
    stale = [
        key
        for key, started in _inflight_started.items()
        if now - started > _INFLIGHT_TTL_SECONDS
    ]
    for key in stale:
        _inflight_keys.discard(key)
        _inflight_started.pop(key, None)


def _get_photo_executor() -> ThreadPoolExecutor:
    global _photo_executor
    with _photo_executor_lock:
        if _photo_executor is None:
            workers = int(getattr(settings, "TELEGRAM_OCR_WORKERS", 2) or 2)
            _photo_executor = ThreadPoolExecutor(
                max_workers=max(1, workers),
                thread_name_prefix="tg-ocr",
            )
        return _photo_executor


def _submit_photo_work(work: Any) -> None:
    """OCR'yi arka planda calistir; testlerde TELEGRAM_INLINE_PHOTOS=True."""
    if getattr(settings, "TELEGRAM_INLINE_PHOTOS", False):
        work()
        return

    def wrapped() -> None:
        from django.db import close_old_connections

        close_old_connections()
        try:
            work()
        except Exception:
            logger.exception("Telegram photo worker failed")
        finally:
            close_old_connections()

    _get_photo_executor().submit(wrapped)


@contextmanager
def _photo_processing_guard(processing_key: str) -> Iterator[None]:
    key = (processing_key or "").strip()
    if not key:
        yield
        return
    with _inflight_lock:
        _prune_stale_inflight()
        if key in _inflight_keys:
            raise PhotoAlreadyProcessing(key)
        _inflight_keys.add(key)
        _inflight_started[key] = time.monotonic()
    try:
        yield
    finally:
        with _inflight_lock:
            _inflight_keys.discard(key)
            _inflight_started.pop(key, None)


@contextmanager
def telegram_lock() -> Iterator[None]:
    acquire_telegram_lock()
    try:
        yield
    finally:
        release_telegram_lock()


@dataclass
class DrainStats:
    ingested: int = 0
    skipped: int = 0
    errors: int = 0
    commands: int = 0
    ignored: int = 0

    def record(self, outcome: HandleOutcome) -> None:
        if outcome == "ingested":
            self.ingested += 1
        elif outcome == "skipped":
            self.skipped += 1
        elif outcome == "error":
            self.errors += 1
        elif outcome == "command":
            self.commands += 1
        else:
            self.ignored += 1


def telegram_configured() -> bool:
    return bool(getattr(settings, "TELEGRAM_BOT_TOKEN", ""))


def _ssl_context() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    try:
        import certifi

        ctx.load_verify_locations(certifi.where())
    except ImportError:
        pass
    return ctx


def _urlopen(req: urllib.request.Request, *, timeout: int = 60):
    return urllib.request.urlopen(req, timeout=timeout, context=_ssl_context())


def _api_url(method: str) -> str:
    token = settings.TELEGRAM_BOT_TOKEN
    return f"https://api.telegram.org/bot{token}/{method}"


def _post(method: str, payload: dict[str, Any]) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        _api_url(method),
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with _urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    if not body.get("ok"):
        raise RuntimeError(body.get("description") or "Telegram API hatası")
    return body


def get_webhook_info() -> dict[str, Any]:
    """getWebhookInfo — polling mi webhook mu anlamak icin."""
    if not telegram_configured():
        return {}
    try:
        body = _post("getWebhookInfo", {})
    except Exception:
        logger.exception("Telegram getWebhookInfo failed")
        return {}
    result = body.get("result")
    return result if isinstance(result, dict) else {}


def clear_webhook_for_polling() -> None:
    """getUpdates icin webhook kapat; bekleyen mesajlar korunur."""
    _post("deleteWebhook", {"drop_pending_updates": False})


def ensure_polling_mode() -> str | None:
    """
    Yerel TELEGRAM.bat / --watch polling kullanir.
    Webhook aciksa Telegram getUpdates'e mesaj vermez — kapatilir.
    """
    info = get_webhook_info()
    url = (info.get("url") or "").strip()
    if not url:
        return None
    clear_webhook_for_polling()
    logger.info("Telegram webhook kaldirildi (polling): %s", url)
    return url


def send_message(
    chat_id: int,
    text: str,
    *,
    parse_mode: str | None = None,
    reply_markup: dict[str, Any] | None = None,
) -> int | None:
    payload: dict[str, Any] = {"chat_id": chat_id, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    if reply_markup is not None:
        payload["reply_markup"] = reply_markup
    try:
        body = _post("sendMessage", payload)
    except Exception:
        if parse_mode:
            logger.warning(
                "Telegram sendMessage HTML failed chat_id=%s — düz metin deneniyor",
                chat_id,
            )
            plain_payload: dict[str, Any] = {
                "chat_id": chat_id,
                "text": text,
            }
            if reply_markup is not None:
                plain_payload["reply_markup"] = reply_markup
            try:
                body = _post("sendMessage", plain_payload)
            except Exception:
                logger.exception(
                    "Telegram sendMessage failed chat_id=%s", chat_id
                )
                return None
        else:
            logger.exception("Telegram sendMessage failed chat_id=%s", chat_id)
            return None
    message_id = (body.get("result") or {}).get("message_id")
    if message_id:
        _track_chat_message(int(chat_id), int(message_id))
    return int(message_id) if message_id else None


def _track_bot_message(chat_id: int, message_id: int) -> None:
    _track_chat_message(chat_id, message_id)


def _normalize_command(text: str) -> str:
    return text.strip().lower().split("@", 1)[0]


def _is_clear_chat_command(text: str) -> bool:
    return _normalize_command(text) in _CLEAR_CHAT_COMMANDS


def _handle_clear_chat(
    chat_id: int,
    user_id: int,
    *,
    command_message_id: int | None = None,
) -> HandleOutcome:
    session = get_session(user_id)
    photo_message_id = session.source_message_id if session else None
    clear_session(user_id)
    extra_ids: list[int] = []
    if photo_message_id:
        extra_ids.append(int(photo_message_id))
    if command_message_id:
        extra_ids.append(int(command_message_id))
    deleted, failed = _purge_chat_messages(chat_id, extra_ids=extra_ids)
    lines = [
        "Sohbet temizlendi.",
        f"Silinen mesaj: {deleted}",
    ]
    if failed:
        lines.append(
            f"Silinemeyen: {failed} (48 saatten eski veya zaten silinmiş olabilir)"
        )
    lines.extend(
        [
            "Bot arka planda dinlemeye devam ediyor — yeni fotoğraf gönderebilirsiniz.",
            "",
            "Not: Telegram menüsündeki 「Sohbeti Sil」 bunu yapmaz; "
            "sohbeti tamamen siler. Temizlik için her zaman /sohbeti_sil kullanın.",
        ]
    )
    confirm_id = send_message(chat_id, "\n".join(lines))
    if confirm_id:

        def _remove_confirmation() -> None:
            time.sleep(4)
            _try_delete_message(chat_id, int(confirm_id))

        threading.Thread(target=_remove_confirmation, daemon=True).start()
    return "command"


def answer_callback_query(callback_query_id: str, *, text: str = "") -> None:
    if not callback_query_id:
        return
    payload: dict[str, Any] = {"callback_query_id": callback_query_id}
    if text:
        payload["text"] = text
    try:
        _post("answerCallbackQuery", payload)
    except Exception:
        logger.exception("Telegram answerCallbackQuery failed id=%s", callback_query_id)


def edit_message_reply_markup(
    chat_id: int,
    message_id: int,
    reply_markup: dict[str, Any] | None,
) -> None:
    if not message_id:
        return
    markup = reply_markup if reply_markup is not None else {"inline_keyboard": []}
    try:
        _post(
            "editMessageReplyMarkup",
            {
                "chat_id": chat_id,
                "message_id": message_id,
                "reply_markup": markup,
            },
        )
    except Exception:
        logger.exception(
            "Telegram editMessageReplyMarkup failed chat_id=%s message_id=%s",
            chat_id,
            message_id,
        )


def _dispatch_conversation_reply(
    chat_id: int,
    reply: ConversationReply,
    *,
    prompt_message_id: int | None = None,
) -> None:
    send_message(chat_id, reply.text)
    if reply.delete_photo_message_id:
        delete_message(chat_id, int(reply.delete_photo_message_id))
    if prompt_message_id:
        edit_message_reply_markup(chat_id, int(prompt_message_id), None)


def delete_message(chat_id: int, message_id: int) -> None:
    """Bot sohbetindeki mesaji temizler (fotoğraf, bot yanıtı vb.)."""
    _try_delete_message(chat_id, message_id)


def _allowed_user(user_id: int | None) -> bool:
    allowed = getattr(settings, "TELEGRAM_ALLOWED_USER_IDS", []) or []
    if not allowed:
        return False
    return user_id in allowed


def _caption_slug(caption: str) -> str:
    return (caption or "").strip().split()[0] if caption else ""


def _resolve_topic(caption: str) -> Topic | None:
    slug = _caption_slug(caption)
    if slug:
        topic = Topic.objects.filter(slug=slug, is_active=True).select_related(
            "subject"
        ).first()
        if topic:
            return topic
        return None
    default_slug = getattr(settings, "TELEGRAM_DEFAULT_TOPIC_SLUG", "") or ""
    if default_slug:
        return Topic.objects.filter(slug=default_slug, is_active=True).first()
    return Topic.objects.filter(is_active=True).order_by(
        "subject__sort_order", "sort_order", "id"
    ).first()


def _download_file(file_id: str) -> tuple[bytes, str]:
    meta = _post("getFile", {"file_id": file_id})
    file_path = meta["result"]["file_path"]
    url = f"https://api.telegram.org/file/bot{settings.TELEGRAM_BOT_TOKEN}/{file_path}"
    with _urlopen(urllib.request.Request(url), timeout=60) as resp:
        data = resp.read()
    ext = file_path.rsplit(".", 1)[-1].lower() if "." in file_path else "jpg"
    mime = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp",
    }.get(ext, "image/jpeg")
    return data, mime


def peek_update_queue() -> tuple[int, int]:
    """Bekleyen guncelleme sayisi (toplam, fotograf). Offset ilerlemez."""
    if not telegram_configured():
        return 0, 0
    token = settings.TELEGRAM_BOT_TOKEN
    url = f"https://api.telegram.org/bot{token}/getUpdates?timeout=0&limit=100"
    try:
        with _urlopen(urllib.request.Request(url), timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ssl.SSLError):
        return 0, 0
    if not data.get("ok"):
        return 0, 0
    updates = data.get("result", [])
    photo_count = 0
    for update in updates:
        message = update.get("message") or update.get("edited_message")
        if message and _extract_image(message) is not None:
            photo_count += 1
    return len(updates), photo_count


def _status_text() -> str:
    pending = pending_telegram_question_count()
    total, photos = peek_update_queue()
    wh = get_webhook_info()
    wh_url = (wh.get("url") or "").strip()
    lines = [
        "HEDEF Kamu — durum",
        "",
        f"Panelde onay bekleyen: {pending}",
    ]
    if wh_url:
        lines.append(
            f"⚠ Webhook aktif: {wh_url}\n"
            "Yerel aktarım için TELEGRAM.bat veya TELEGRAM-WATCH.bat çalıştırın "
            "(webhook otomatik kapatılır)."
        )
    if telegram_lock_active():
        lines.append("Aktarım: şu an çalışıyor (TELEGRAM.bat / WATCH açık).")
    elif not wh_url:
        lines.append(
            "Aktarım: kapalı — fotoğraf iletmek için TELEGRAM-WATCH.bat açık olmalı."
        )
    if photos:
        lines.append(
            f"Telegram kuyruğu: {photos} fotoğraf "
            f"({total} mesaj) — TELEGRAM.bat ile işlenecek."
        )
    elif total:
        lines.append(
            f"Telegram kuyruğu: {total} mesaj (fotoğraf yok) — "
            "komut/ metin bekliyor olabilir."
        )
    else:
        lines.append("Telegram kuyruğu: boş — yeni fotoğraf beklenmiyor.")
    lines.append("")
    lines.append("Eve gelince TELEGRAM.bat çalıştırın veya /durum ile tekrar bakın.")
    return "\n".join(lines)


def register_bot_commands() -> None:
    """Telegram komut menüsü — kullanıcı /sohbeti_sil görsün, menüden Sil kullanmasın."""
    if not telegram_configured():
        return
    commands = [
        {"command": "durum", "description": "Panel ve kuyruk özeti"},
        {
            "command": "sohbeti_sil",
            "description": "Bot mesajlarını temizle (⋮ menüsündeki Sil değil!)",
        },
        {"command": "eski", "description": "Kaçan fotoğraflar rehberi"},
        {"command": "iptal", "description": "Bekleyen çözüm adımını iptal"},
        {"command": "help", "description": "Yardım ve uyarılar"},
    ]
    try:
        _post("setMyCommands", {"commands": commands})
    except Exception:
        logger.exception("Telegram setMyCommands failed")


def _help_text() -> str:
    default_slug = getattr(settings, "TELEGRAM_DEFAULT_TOPIC_SLUG", "turkce_anlam")
    return (
        "HEDEF Kamu soru botu\n\n"
        "⚠️ Sohbeti temizlemek için Telegram menüsündeki "
        "「Sohbeti Sil」 KULLANMAYIN — sohbet tamamen silinir, "
        "botu yeniden açmanız gerekir (BotFather gerekmez; bota /start yazmanız yeter).\n"
        "✅ Bunun yerine komut yazın: /sohbeti_sil\n"
        "   (yalnızca bot mesajları silinir, arka plan dinlemesi devam eder)\n\n"
        "• Soru fotoğrafı gönderin (altına isteğe bağlı konu slug, "
        f"örn. {default_slug}).\n"
        "• Konu yazmazsanız ders/konu fotoğraftan otomatik algılanır.\n"
        "• PC kapalıyken bot ~24 saat kuyruğu dinler.\n"
        "• Eve gelince TELEGRAM-WATCH.bat açık tutun (sürekli dinler).\n"
        "• Tek seferlik aktarım: TELEGRAM.bat\n"
        "• Django/panel açık olması yetmez — Telegram bat ayrı çalışmalı.\n"
        "• 24 saatten eski veya kaçan fotoğraflar: eski mesajı "
        "seç → İlet (forward) → bota gönder.\n"
        "• İşlenen fotoğraflar: çözüm eklerseniz (evet) sohbetten silinir; "
        "hayır derseniz fotoğraf kalır.\n"
        "• Aynı fotoğrafı tekrar iletirseniz uyarı alırsınız.\n"
        "• Panel → Onay bekleyen sorular\n\n"
        "• Fotoğraf sonrası çözüm eklemek için Evet/Hayır düğmeleri çıkar; "
        "Google'dan kopyaladığınız metni yapıştırabilirsiniz.\n\n"
        "/durum — panel + kuyruk özeti\n"
        "/eski — kaçan fotoğraflar için kısa rehber\n"
        "/sohbeti_sil — bot mesajlarını temizle (menüden Sil değil!)\n"
        "/iptal — bekleyen çözüm adımını iptal"
    )


def _missed_photos_help() -> str:
    return (
        "Kaçan / eski soru fotoğrafları\n\n"
        "1) Eski fotoğrafınız kendi sohbetinizde durur (silinmez).\n"
        "2) Fotoğrafa uzun bas → İlet → @hedefkamubot\n"
        "3) TELEGRAM.bat açıkken iletilenler işlenir; bot sohbetinden silinir.\n"
        "4) Aynı fotoğrafı yanlışlıkla tekrar iletirseniz bot uyarır.\n"
        "5) Birden fazla fotoğraf: çoklu seç → ilet.\n\n"
        "İletirken altına konu slug yazabilirsiniz (örn. mat_problem)."
    )


def _extract_image(message: dict[str, Any]) -> tuple[str, str] | None:
    photos = message.get("photo") or []
    if photos:
        largest = photos[-1]
        file_id = largest.get("file_id")
        unique_id = largest.get("file_unique_id") or ""
        if file_id:
            return str(file_id), str(unique_id)
    document = message.get("document") or {}
    mime = (document.get("mime_type") or "").lower()
    if mime.startswith("image/"):
        file_id = document.get("file_id")
        unique_id = document.get("file_unique_id") or ""
        if file_id:
            return str(file_id), str(unique_id)
    return None


def _is_forwarded(message: dict[str, Any]) -> bool:
    return bool(message.get("forward_origin") or message.get("forward_date"))


def _find_by_file_unique_id(file_unique_id: str) -> Question | None:
    uid = (file_unique_id or "").strip()
    if not uid:
        return None
    return Question.objects.filter(telegram_file_unique_id=uid).first()


def _find_existing_telegram_question(
    *,
    chat_id: int,
    message_id: int,
    file_unique_id: str,
) -> tuple[Question | None, Literal["file", "message"] | None]:
    by_file = _find_by_file_unique_id(file_unique_id)
    if by_file is not None:
        return by_file, "file"
    by_message = Question.objects.filter(
        telegram_chat_id=chat_id,
        telegram_message_id=message_id,
        submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
    ).first()
    if by_message is not None:
        return by_message, "message"
    return None, None


def _find_existing_after_conflict(
    *,
    chat_id: int,
    message_id: int,
    file_unique_id: str,
) -> tuple[Question | None, Literal["file", "message"] | None]:
    """IntegrityError sonrasi — baska surec az once kaydetmis olabilir."""
    for delay in (0.0, 0.2, 0.6, 1.2):
        if delay:
            time.sleep(delay)
        existing, match = _find_existing_telegram_question(
            chat_id=chat_id,
            message_id=message_id,
            file_unique_id=file_unique_id,
        )
        if existing is not None:
            return existing, match
    return None, None


def _duplicate_warning(
    existing: Question,
    match: Literal["file", "message"],
    *,
    forwarded: bool,
) -> str:
    status = "yayında" if existing.is_published else "onay bekliyor"
    if match == "file" or forwarded:
        return (
            "Bu soruyu daha önce ilettiniz — sunucuya zaten aktarıldı.\n"
            f"Kimlik: {existing.public_id} ({status})\n"
            "Tekrar iletmenize gerek yok."
        )
    return f"Bu fotoğraf zaten kayıtlı: {existing.public_id} ({status})."


def _escape_html(text: str) -> str:
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def _format_elapsed(seconds: float) -> str:
    total = max(1, int(round(seconds)))
    if total < 60:
        return f"{total} sn"
    minutes, secs = divmod(total, 60)
    if secs:
        return f"{minutes} dk {secs} sn"
    return f"{minutes} dk"


def _build_ingest_success_html(
    *,
    topic: Topic,
    question: Question,
    pending: int,
    elapsed_seconds: float,
    forwarded: bool,
    partial: bool,
    duplicate: Question | None,
    include_solution_prompt: bool,
    topic_auto_detected: bool = False,
) -> str:
    duration = _escape_html(_format_elapsed(elapsed_seconds))
    subject = _escape_html(topic.subject.name)
    topic_name = _escape_html(topic.name)
    public_id = _escape_html(question.public_id)

    lines: list[str] = []
    if forwarded:
        lines.append("(Eski fotoğraf iletildi — işlendi.)")
    lines.append(
        f"<b>Soru alındı — onay bekliyor.</b>  <i>⏱ {duration}</i>"
    )
    lines.append(f"Konu: {subject} · {topic_name}")
    if topic_auto_detected:
        lines.append("<i>(Konu fotoğraftan otomatik algılandı)</i>")
    lines.append(f"Kimlik: <code>{public_id}</code>")
    if partial:
        lines.append("Uyarı: kısmi OCR — panelden kontrol edin.")
    if duplicate is not None:
        dup_id = _escape_html(duplicate.public_id)
        lines.append(
            "🔴 <b>Uyarı: benzer soru var "
            f"(<code>{dup_id}</code>).</b>"
        )
    lines.append(f"Bekleyen toplam: {pending}")
    if include_solution_prompt:
        lines.append("")
        lines.extend(
            _escape_html(line) for line in solution_prompt_message().split("\n")
        )
    return "\n".join(lines)


def _build_ingest_success_plain(
    *,
    topic: Topic,
    question: Question,
    pending: int,
    elapsed_seconds: float,
    forwarded: bool,
    partial: bool,
    duplicate: Question | None,
    include_solution_prompt: bool,
    topic_auto_detected: bool = False,
) -> str:
    duration = _format_elapsed(elapsed_seconds)
    lines: list[str] = []
    if forwarded:
        lines.append("(Eski fotoğraf iletildi — işlendi.)")
    lines.append(f"Soru alındı — onay bekliyor.  ⏱ {duration}")
    lines.append(f"Konu: {topic.subject.name} · {topic.name}")
    if topic_auto_detected:
        lines.append("(Konu fotoğraftan otomatik algılandı)")
    lines.append(f"Kimlik: {question.public_id}")
    if partial:
        lines.append("Uyarı: kısmi OCR — panelden kontrol edin.")
    if duplicate is not None:
        lines.append(
            f"🔴 Uyarı: benzer soru var ({duplicate.public_id})."
        )
    lines.append(f"Bekleyen toplam: {pending}")
    if include_solution_prompt:
        lines.append("")
        lines.append(solution_prompt_message())
    return "\n".join(lines)


def _send_ingest_success(
    chat_id: int,
    *,
    topic: Topic,
    question: Question,
    pending: int,
    elapsed_seconds: float,
    forwarded: bool,
    partial: bool,
    duplicate: Question | None,
    include_solution_prompt: bool,
    topic_auto_detected: bool = False,
) -> None:
    keyboard = solution_prompt_keyboard() if include_solution_prompt else None
    reply_html = _build_ingest_success_html(
        topic=topic,
        question=question,
        pending=pending,
        elapsed_seconds=elapsed_seconds,
        forwarded=forwarded,
        partial=partial,
        duplicate=duplicate,
        include_solution_prompt=include_solution_prompt,
        topic_auto_detected=topic_auto_detected,
    )
    sent = send_message(
        chat_id,
        reply_html,
        parse_mode="HTML",
        reply_markup=keyboard,
    )
    if sent is None:
        reply_plain = _build_ingest_success_plain(
            topic=topic,
            question=question,
            pending=pending,
            elapsed_seconds=elapsed_seconds,
            forwarded=forwarded,
            partial=partial,
            duplicate=duplicate,
            include_solution_prompt=include_solution_prompt,
            topic_auto_detected=topic_auto_detected,
        )
        send_message(chat_id, reply_plain, reply_markup=keyboard)


def _ingest_photo_worker(
    *,
    message: dict[str, Any],
    chat_id: int,
    message_id: int,
    file_id: str,
    file_unique_id: str,
    topic: Topic,
    explicit_topic: bool,
    forwarded: bool,
) -> HandleOutcome:
    processing_key = _processing_key(int(chat_id), message_id)
    try:
        with _photo_processing_guard(processing_key):
            started = time.perf_counter()
            try:
                image_bytes, mime = _download_file(file_id)
            except (urllib.error.URLError, RuntimeError, TimeoutError) as exc:
                send_message(
                    chat_id,
                    f"Fotoğraf indirilemedi: {exc}\n{_retry_hint()}",
                )
                return "error"

            ext = "jpg" if "jpeg" in mime else mime.split("/")[-1]
            filename = f"telegram_{message_id}.{ext}"
            buffer = io.BytesIO(image_bytes)

            try:
                result = ingest_question_from_image(
                    buffer,
                    topic=topic,
                    filename=filename,
                    mime=mime,
                    publish=False,
                    submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                    telegram_chat_id=int(chat_id),
                    telegram_message_id=message_id,
                    telegram_file_unique_id=file_unique_id,
                    allow_duplicate=True,
                    auto_classify_topic=not explicit_topic,
                )
            except IntegrityError:
                logger.warning(
                    "Telegram ingest IntegrityError chat=%s msg=%s file_uid=%s",
                    chat_id,
                    message_id,
                    file_unique_id,
                )
                existing, match = _find_existing_after_conflict(
                    chat_id=int(chat_id),
                    message_id=message_id,
                    file_unique_id=file_unique_id,
                )
                if existing is not None:
                    send_message(
                        chat_id,
                        _duplicate_warning(
                            existing, match or "file", forwarded=forwarded
                        ),
                    )
                    delete_message(int(chat_id), message_id)
                    return "skipped"
                send_message(
                    chat_id,
                    "Kaydedilemedi: kayıt çakışması (eşzamanlı yazma).\n"
                    "Birkaç saniye bekleyip tekrar gönderin.\n"
                    f"{_retry_hint()}",
                )
                return "error"

            if not result.ok or result.question is None:
                send_message(
                    chat_id,
                    f"Kaydedilemedi: {result.error or 'bilinmeyen hata'}\n{_retry_hint()}",
                )
                return "error"

            pending = Question.objects.filter(
                submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                is_published=False,
            ).count()
            elapsed = time.perf_counter() - started
            assigned_topic = result.question.topic

            from_user = message.get("from") or {}
            user_id = from_user.get("id")
            if user_id is not None:
                try:
                    start_solution_prompt(
                        int(user_id),
                        int(chat_id),
                        result.question,
                        source_message_id=message_id,
                    )
                except Exception:
                    logger.exception(
                        "Telegram solution session start failed user_id=%s question=%s",
                        user_id,
                        result.question.public_id,
                    )
                _send_ingest_success(
                    int(chat_id),
                    topic=assigned_topic,
                    question=result.question,
                    pending=pending,
                    elapsed_seconds=elapsed,
                    forwarded=forwarded,
                    partial=result.partial,
                    duplicate=result.duplicate,
                    include_solution_prompt=True,
                    topic_auto_detected=result.topic_auto_detected,
                )
            else:
                _send_ingest_success(
                    int(chat_id),
                    topic=assigned_topic,
                    question=result.question,
                    pending=pending,
                    elapsed_seconds=elapsed,
                    forwarded=forwarded,
                    partial=result.partial,
                    duplicate=result.duplicate,
                    include_solution_prompt=False,
                    topic_auto_detected=result.topic_auto_detected,
                )
                delete_message(int(chat_id), message_id)
            return "ingested"
    except PhotoAlreadyProcessing:
        send_message(
            chat_id,
            "Bu mesaj zaten OCR kuyruğunda.\n"
            "Farklı bir soru fotoğrafı gönderdiyseniz sırayla işlenecek — "
            "birkaç saniye bekleyin.",
        )
        return "skipped"


def _process_photo_message(message: dict[str, Any], chat_id: int) -> HandleOutcome:
    extracted = _extract_image(message)
    if extracted is None:
        return "ignored"

    file_id, file_unique_id = extracted
    caption = (message.get("caption") or "").strip()
    caption_slug = _caption_slug(caption)
    explicit_topic = bool(caption_slug)
    topic = _resolve_topic(caption)
    if topic is None:
        if caption_slug:
            send_message(
                chat_id,
                f"Konu bulunamadı: {caption_slug} — "
                "düzeltin veya slug yazmadan gönderin.\n"
                f"{_retry_hint()}",
            )
        else:
            send_message(
                chat_id,
                "Aktif konu bulunamadı. Önce müfredatı seed edin.\n"
                f"{_retry_hint()}",
            )
        return "error"

    message_id = int(message.get("message_id") or 0)
    forwarded = _is_forwarded(message)
    existing, match = _find_existing_telegram_question(
        chat_id=int(chat_id),
        message_id=message_id,
        file_unique_id=file_unique_id,
    )
    if existing is not None:
        send_message(
            chat_id,
            _duplicate_warning(existing, match or "file", forwarded=forwarded),
        )
        delete_message(int(chat_id), message_id)
        return "skipped"

    processing_key = _processing_key(int(chat_id), message_id)
    with _inflight_lock:
        _prune_stale_inflight()
        if processing_key in _inflight_keys:
            send_message(
                chat_id,
                "Bu mesaj zaten OCR kuyruğunda.\n"
                "Farklı bir soru fotoğrafı gönderdiyseniz sırayla işlenecek — "
                "birkaç saniye bekleyin.",
            )
            return "skipped"

    send_message(
        chat_id,
        "📷 Fotoğraf alındı, OCR başlıyor…",
    )
    if getattr(settings, "TELEGRAM_INLINE_PHOTOS", False):
        return _ingest_photo_worker(
            message=message,
            chat_id=int(chat_id),
            message_id=message_id,
            file_id=file_id,
            file_unique_id=file_unique_id,
            topic=topic,
            explicit_topic=explicit_topic,
            forwarded=forwarded,
        )
    _submit_photo_work(
        lambda: _ingest_photo_worker(
            message=message,
            chat_id=int(chat_id),
            message_id=message_id,
            file_id=file_id,
            file_unique_id=file_unique_id,
            topic=topic,
            explicit_topic=explicit_topic,
            forwarded=forwarded,
        )
    )
    return "ingested"


def _handle_callback_query(callback: dict[str, Any]) -> HandleOutcome:
    from_user = callback.get("from") or {}
    user_id = from_user.get("id")
    callback_id = str(callback.get("id") or "")

    if not _allowed_user(user_id):
        answer_callback_query(callback_id, text="Yetkisiz hesap.")
        return "unauthorized"

    if not telegram_configured():
        answer_callback_query(callback_id, text="Bot yapılandırılmamış.")
        return "error"

    message = callback.get("message") or {}
    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    message_id = int(message.get("message_id") or 0)
    data = (callback.get("data") or "").strip()

    if user_id is None or chat_id is None:
        answer_callback_query(callback_id)
        return "ignored"

    if message_id:
        _track_chat_message(int(chat_id), message_id)

    reply = try_handle_conversation_callback(data, int(user_id))
    answer_callback_query(callback_id)
    if reply is None:
        return "ignored"

    _dispatch_conversation_reply(
        int(chat_id),
        reply,
        prompt_message_id=message_id or None,
    )
    return "command"


def handle_update(update: dict[str, Any]) -> HandleOutcome:
    callback = update.get("callback_query")
    if callback:
        return _handle_callback_query(callback)

    message = update.get("message") or update.get("edited_message")
    if not message:
        return "ignored"

    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    if chat_id is None:
        return "ignored"

    message_id = int(message.get("message_id") or 0)
    if message_id:
        _track_chat_message(int(chat_id), message_id)

    from_user = message.get("from") or {}
    user_id = from_user.get("id")

    if not _allowed_user(user_id):
        send_message(
            chat_id,
            "Bu bot yalnızca yetkili hesaplar içindir. "
            "TELEGRAM_ALLOWED_USER_IDS ayarını kontrol edin.",
        )
        return "unauthorized"

    text = (message.get("text") or "").strip()
    if text.startswith("/start") or text.startswith("/help"):
        send_message(chat_id, _help_text())
        return "command"
    if text.startswith("/eski"):
        send_message(chat_id, _missed_photos_help())
        return "command"
    if text.startswith("/durum"):
        send_message(chat_id, _status_text())
        return "command"
    if text.startswith("/iptal"):
        reply = try_handle_conversation(int(user_id), text, cancel=True)
        if reply is not None:
            send_message(chat_id, reply.text)
        else:
            send_message(chat_id, "İptal edilecek bir adım yok.")
        return "command"
    if text and _is_clear_chat_command(text):
        return _handle_clear_chat(
            int(chat_id),
            int(user_id),
            command_message_id=message_id or None,
        )

    if not telegram_configured():
        send_message(chat_id, "Bot yapılandırılmamış (TELEGRAM_BOT_TOKEN).")
        return "error"

    if _extract_image(message) is not None:
        return _process_photo_message(message, int(chat_id))

    if text and user_id is not None:
        entities = message.get("entities") or []
        reply = try_handle_conversation(
            int(user_id),
            text,
            entities=entities,
        )
        if reply is not None:
            _dispatch_conversation_reply(int(chat_id), reply)
            return "command"

    if text:
        send_message(
            chat_id,
            "Soru eklemek için fotoğraf gönderin veya eski fotoğrafı "
            "İlet (forward) yapın. /eski",
        )
        return "command"
    return "ignored"


def notify_drain_complete(stats: DrainStats) -> None:
    """Kuyruk bosaldiginda Telegram ozeti."""
    if not telegram_configured():
        return
    allowed = getattr(settings, "TELEGRAM_ALLOWED_USER_IDS", []) or []
    pending = pending_telegram_question_count()
    lines = [
        "Aktarım tamamlandı.",
        f"Yeni soru: {stats.ingested}",
    ]
    if stats.skipped:
        lines.append(f"Zaten kayıtlı (atlandı): {stats.skipped}")
    if stats.errors:
        lines.append(drain_error_summary(stats.errors))
        lines.append(_DRAIN_ERROR_FOOTER)
    lines.append(f"Panelde onay bekleyen: {pending}")
    if stats.ingested == 0 and stats.skipped == 0 and stats.errors == 0:
        lines.append("Telegram kuyruğunda işlenecek fotoğraf kalmadı.")
    elif stats.errors:
        pass
    else:
        lines.append("Telegram kuyruğu boş — PC'yi kapatabilirsiniz.")
    text = "\n".join(lines)
    for user_id in allowed:
        try:
            send_message(int(user_id), text)
        except Exception:
            logger.exception("Drain notify failed user_id=%s", user_id)


def set_webhook(public_base_url: str, secret: str) -> str:
    base = public_base_url.rstrip("/")
    url = f"{base}/api/v1/telegram/webhook/{secret}/"
    _post("setWebhook", {"url": url, "allowed_updates": ["message", "edited_message"]})
    return url
