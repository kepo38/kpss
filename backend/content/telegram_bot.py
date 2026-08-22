"""Telegram bot — soru fotoğrafı → OCR → onay bekleyen soru."""

from __future__ import annotations

import io
import json
import logging
import os
import ssl
import urllib.error
import urllib.request
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
    solution_prompt_message,
    start_solution_prompt,
    try_handle_conversation,
)

logger = logging.getLogger(__name__)

HandleOutcome = Literal[
    "ingested", "skipped", "error", "command", "ignored", "unauthorized"
]

_RETRY_HINT = "Bir sonraki TELEGRAM.bat'ta tekrar denenecek."

_DRAIN_ERROR_LINE = (
    "Hata: {count} (fotoğraflar bot sohbetinde — TELEGRAM.bat'ı tekrar çalıştırın)"
)
_DRAIN_ERROR_FOOTER = (
    "Tekrar çalıştırınca aynı fotoğraflar otomatik yeniden denenecek."
)


def drain_error_summary(count: int) -> str:
    return _DRAIN_ERROR_LINE.format(count=count)


def drain_error_footer() -> str:
    return _DRAIN_ERROR_FOOTER


class TelegramBotLockError(RuntimeError):
    """TELEGRAM.bat / run_telegram_bot zaten calisiyor."""


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


def send_message(chat_id: int, text: str, *, parse_mode: str | None = None) -> None:
    payload: dict[str, Any] = {"chat_id": chat_id, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    try:
        _post("sendMessage", payload)
    except Exception:
        logger.exception("Telegram sendMessage failed chat_id=%s", chat_id)


def delete_message(chat_id: int, message_id: int) -> None:
    """Bot sohbetindeki islenmis fotografi temizler."""
    if not message_id:
        return
    try:
        _post("deleteMessage", {"chat_id": chat_id, "message_id": message_id})
    except Exception:
        logger.exception(
            "Telegram deleteMessage failed chat_id=%s message_id=%s",
            chat_id,
            message_id,
        )


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


def _help_text() -> str:
    default_slug = getattr(settings, "TELEGRAM_DEFAULT_TOPIC_SLUG", "turkce_anlam")
    return (
        "HEDEF Kamu soru botu\n\n"
        "• Soru fotoğrafı gönderin (altına isteğe bağlı konu slug, "
        f"örn. {default_slug}).\n"
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
        "• Fotoğraf sonrası çözüm eklemek için evet deyin; Google'dan "
        "kopyaladığınız metni yapıştırın.\n\n"
        "/durum — panel + kuyruk özeti\n"
        "/eski — kaçan fotoğraflar için kısa rehber\n"
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


def _find_existing_telegram_question(
    *,
    chat_id: int,
    message_id: int,
    file_unique_id: str,
) -> tuple[Question | None, Literal["file", "message"] | None]:
    if file_unique_id:
        by_file = Question.objects.filter(
            telegram_file_unique_id=file_unique_id,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        ).first()
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


def _process_photo_message(message: dict[str, Any], chat_id: int) -> HandleOutcome:
    extracted = _extract_image(message)
    if extracted is None:
        return "ignored"

    file_id, file_unique_id = extracted
    caption = (message.get("caption") or "").strip()
    caption_slug = _caption_slug(caption)
    topic = _resolve_topic(caption)
    if topic is None:
        if caption_slug:
            send_message(
                chat_id,
                f"Konu bulunamadı: {caption_slug} — "
                "düzeltin veya slug yazmadan gönderin.\n"
                f"{_RETRY_HINT}",
            )
        else:
            send_message(
                chat_id,
                "Aktif konu bulunamadı. Önce müfredatı seed edin.\n"
                f"{_RETRY_HINT}",
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

    try:
        image_bytes, mime = _download_file(file_id)
    except (urllib.error.URLError, RuntimeError, TimeoutError) as exc:
        send_message(
            chat_id,
            f"Fotoğraf indirilemedi: {exc}\n{_RETRY_HINT}",
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
        )
    except IntegrityError:
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
        send_message(
            chat_id,
            f"Kaydedilemedi: aynı fotoğraf zaten işleniyor.\n{_RETRY_HINT}",
        )
        return "error"

    if not result.ok or result.question is None:
        send_message(
            chat_id,
            f"Kaydedilemedi: {result.error or 'bilinmeyen hata'}\n{_RETRY_HINT}",
        )
        return "error"

    pending = Question.objects.filter(
        submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        is_published=False,
    ).count()
    lines = [
        "Soru alındı — onay bekliyor.",
        f"Konu: {topic.subject.name} · {topic.name}",
        f"Kimlik: {result.question.public_id}",
    ]
    if forwarded:
        lines.insert(1, "(Eski fotoğraf iletildi — işlendi.)")
    if result.partial:
        lines.append("Uyarı: kısmi OCR — panelden kontrol edin.")
    if result.duplicate:
        lines.append(
            f"Uyarı: benzer soru var ({result.duplicate.public_id})."
        )
    lines.append(f"Bekleyen toplam: {pending}")
    send_message(chat_id, "\n".join(lines))

    from_user = message.get("from") or {}
    user_id = from_user.get("id")
    if user_id is not None:
        start_solution_prompt(
            int(user_id),
            int(chat_id),
            result.question,
            source_message_id=message_id,
        )
        send_message(chat_id, solution_prompt_message())
    else:
        delete_message(int(chat_id), message_id)

    return "ingested"


def handle_update(update: dict[str, Any]) -> HandleOutcome:
    message = update.get("message") or update.get("edited_message")
    if not message:
        return "ignored"

    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    if chat_id is None:
        return "ignored"

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

    if not telegram_configured():
        send_message(chat_id, "Bot yapılandırılmamış (TELEGRAM_BOT_TOKEN).")
        return "error"

    if _extract_image(message) is not None:
        return _process_photo_message(message, int(chat_id))

    if text and user_id is not None:
        reply = try_handle_conversation(int(user_id), text)
        if reply is not None:
            send_message(chat_id, reply.text)
            if reply.delete_photo_message_id:
                delete_message(int(chat_id), int(reply.delete_photo_message_id))
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
