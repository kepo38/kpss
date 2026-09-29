"""Onay bekleyen Telegram sorularını reddet + file_id olmadan yeniden tara.

Telegram ``file_id`` DB'de tutulmaz; ``chat_id`` + ``message_id`` ile
``forwardMessage`` → yeni ``file_id`` → ``getFile`` ile fotoğraf yeniden
indirilir. Gemini kota/429'da Tesseract çöpü panele yazılmaz; kuyruk
kalır ve komut idempotent devam eder.

Kullanım:
  python manage.py reingest_pending_telegram --dump-queue --dry-run
  python manage.py reingest_pending_telegram --dump-queue --reject
  python manage.py reingest_pending_telegram --process --limit 5
"""

from __future__ import annotations

import io
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import IntegrityError

from content.models import OcrIngestLog, Question
from content.ocr_gemini import (
    gemini_quota_cooldown_active,
    gemini_quota_cooldown_remaining_sec,
    is_gemini_quota_error,
)
from content.ocr_ingest import ingest_question_from_image
from content.osym_archive import parse_telegram_caption_archive_label, resolve_to_catalog_key
from content.osym_cikmis import normalize_osym_cikmis_label
from content.panel_context import pending_telegram_questions_qs
from content.telegram_bot import (
    _download_file,
    _extract_image,
    _parse_photo_caption,
    _post,
    _resolve_topic,
    delete_message,
    telegram_configured,
)

DEFAULT_QUEUE_PATH = Path(settings.BASE_DIR) / "reingest_telegram_queue.json"
DBG_PUBLIC_IDS = frozenset({"q_dbg_cap"})


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _is_tesseract_engine(engine: str) -> bool:
    eng = (engine or "").strip().lower()
    return "tesseract" in eng and "gemini" not in eng


def _apply_archive_label(question: Question, archive_label: str) -> None:
    label_raw = (archive_label or "").strip()
    if not label_raw:
        return
    label = resolve_to_catalog_key(label_raw) or normalize_osym_cikmis_label(label_raw)
    if not label:
        return
    question.osym_sordu = True
    question.osym_cikmis_adi = label
    sol = (question.solution or "").strip()
    if sol and normalize_osym_cikmis_label(sol).casefold() == (
        normalize_osym_cikmis_label(label).casefold()
    ):
        question.solution = ""
    question.save(
        update_fields=[
            "osym_sordu",
            "osym_cikmis_adi",
            "solution",
            "updated_at",
        ]
    )


def _forward_and_download(
    chat_id: int, message_id: int
) -> tuple[bytes, str, str, str, str]:
    """forwardMessage → extract file → delete forward.

    Returns: (image_bytes, mime, file_unique_id, caption, file_id)
    """
    body = _post(
        "forwardMessage",
        {
            "chat_id": int(chat_id),
            "from_chat_id": int(chat_id),
            "message_id": int(message_id),
        },
    )
    result = body.get("result") or {}
    new_msg_id = int(result.get("message_id") or 0)
    caption = (result.get("caption") or "").strip()
    try:
        extracted = _extract_image(result)
        if extracted is None:
            raise RuntimeError("İletilen mesajda fotoğraf/doküman yok")
        file_id, file_unique_id = extracted
        image_bytes, mime = _download_file(file_id)
        return image_bytes, mime, str(file_unique_id or ""), caption, str(file_id)
    finally:
        if new_msg_id:
            try:
                delete_message(int(chat_id), new_msg_id)
            except Exception:  # noqa: BLE001 — temizlik best-effort
                pass


class Command(BaseCommand):
    help = (
        "Onay bekleyen Telegram sorularını kuyruğa alıp reddeder; "
        "forwardMessage ile fotoğrafları yeniden Gemini OCR'dan geçirir."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--queue-file",
            type=str,
            default=str(DEFAULT_QUEUE_PATH),
            help="Kalıcı re-ingest kuyruk JSON yolu.",
        )
        parser.add_argument(
            "--dump-queue",
            action="store_true",
            help="Mevcut onay bekleyenlerden kuyruk dosyası yaz (reject yok).",
        )
        parser.add_argument(
            "--reject",
            action="store_true",
            help="Kuyruktaki (veya dump sonrası) unpublished Telegram sorularını sil.",
        )
        parser.add_argument(
            "--process",
            action="store_true",
            help="Kuyruktaki pending öğeleri yeniden tara (Gemini kalite kapısı).",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Bu çalıştırmada en fazla N öğe işle (0=hepsi / kota kadar).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Yazmadan / silmeden / Gemini çağrısı yapmadan listele.",
        )
        parser.add_argument(
            "--include-dbg",
            action="store_true",
            help="q_dbg_cap gibi sahte kayıtları da kuyruğa al.",
        )
        parser.add_argument(
            "--sleep",
            type=float,
            default=1.5,
            help="Başarılı Gemini ingest sonrası bekleme (sn).",
        )

    def handle(self, *args, **options):
        queue_path = Path(options["queue_file"])
        dry_run = bool(options["dry_run"])
        do_dump = bool(options["dump_queue"])
        do_reject = bool(options["reject"])
        do_process = bool(options["process"])
        include_dbg = bool(options["include_dbg"])
        limit = int(options["limit"] or 0)
        sleep_sec = float(options["sleep"] or 0)

        if not (do_dump or do_reject or do_process):
            raise CommandError(
                "En az biri gerekli: --dump-queue, --reject, --process"
            )

        if do_dump:
            queue = self._build_queue(include_dbg=include_dbg)
            if dry_run:
                self.stdout.write(
                    f"[dry-run] Kuyruk adayı: {len(queue['items'])} "
                    f"(reject edilmeyecek / yazılmayacak)"
                )
                for item in queue["items"][:10]:
                    self.stdout.write(
                        f"  {item['old_public_id']} chat={item['chat_id']} "
                        f"msg={item['message_id']} uid={(item['file_unique_id'] or '')[:24]}"
                    )
                if len(queue["items"]) > 10:
                    self.stdout.write(f"  … +{len(queue['items']) - 10} daha")
            else:
                self._save_queue(queue_path, queue)
                self.stdout.write(
                    self.style.SUCCESS(
                        f"Kuyruk yazıldı: {queue_path} ({len(queue['items'])} öğe)"
                    )
                )

        if do_reject:
            if dry_run:
                qs = pending_telegram_questions_qs()
                self.stdout.write(f"[dry-run] Reddedilecek: {qs.count()}")
            else:
                if not queue_path.is_file() and not do_dump:
                    raise CommandError(
                        "Reject öncesi kuyruk yok — önce --dump-queue çalıştırın."
                    )
                rejected = self._reject_pending(include_dbg=True)
                self.stdout.write(
                    self.style.WARNING(f"Reddedildi (silindi): {rejected}")
                )

        if do_process:
            if not telegram_configured():
                raise CommandError("TELEGRAM_BOT_TOKEN tanımlı değil.")
            if dry_run:
                queue = self._load_queue(queue_path)
                pending = [
                    i for i in queue.get("items", []) if i.get("status") == "pending"
                ]
                self.stdout.write(
                    f"[dry-run] İşlenecek pending: {len(pending)} "
                    f"(limit={limit or '∞'})"
                )
                return
            stats = self._process_queue(
                queue_path,
                limit=limit,
                sleep_sec=sleep_sec,
            )
            self.stdout.write(
                "Özet: "
                f"ok={stats['ok']} failed={stats['failed']} "
                f"quota_stop={stats['quota_stop']} "
                f"remaining_pending={stats['remaining_pending']} "
                f"skipped_done={stats['skipped_done']}"
            )

    def _build_queue(self, *, include_dbg: bool) -> dict[str, Any]:
        qs = pending_telegram_questions_qs().order_by("id")
        items: list[dict[str, Any]] = []
        for q in qs:
            if not include_dbg and q.public_id in DBG_PUBLIC_IDS:
                continue
            if not q.telegram_chat_id or not q.telegram_message_id:
                continue
            items.append(
                {
                    "old_public_id": q.public_id,
                    "old_pk": q.pk,
                    "chat_id": int(q.telegram_chat_id),
                    "message_id": int(q.telegram_message_id),
                    "file_unique_id": (q.telegram_file_unique_id or "").strip(),
                    "osym_cikmis_adi": (q.osym_cikmis_adi or "").strip(),
                    "source_image_hash": (q.source_image_hash or "").strip(),
                    "status": "pending",
                    "new_public_id": "",
                    "error": "",
                    "processed_at": None,
                }
            )
        return {
            "created_at": _utc_now_iso(),
            "note": (
                "file_id DB'de yok; re-fetch forwardMessage(chat_id,message_id) "
                "ile yapılıyor. Watch bot kapalıyken --process çalıştırın."
            ),
            "items": items,
        }

    def _save_queue(self, path: Path, queue: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(
            json.dumps(queue, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        tmp.replace(path)

    def _load_queue(self, path: Path) -> dict[str, Any]:
        if not path.is_file():
            raise CommandError(f"Kuyruk dosyası yok: {path}")
        return json.loads(path.read_text(encoding="utf-8"))

    def _reject_pending(self, *, include_dbg: bool) -> int:
        """panel_pending_question_reject ile aynı: hard delete."""
        qs = list(pending_telegram_questions_qs().order_by("id"))
        count = 0
        for q in qs:
            if not include_dbg and q.public_id in DBG_PUBLIC_IDS:
                continue
            # Görsel zaten policy gereği boş; yine de alanları temizle.
            for field_name in (
                "image",
                "solution_image",
                "option_a_image",
                "option_b_image",
                "option_c_image",
                "option_d_image",
                "option_e_image",
            ):
                field = getattr(q, field_name, None)
                if field and getattr(field, "name", ""):
                    try:
                        field.delete(save=False)
                    except Exception:  # noqa: BLE001
                        pass
                    setattr(q, field_name, None)
            public_id = q.public_id
            q.delete()
            count += 1
            self.stdout.write(f"  rejected {public_id}")
        return count

    def _process_queue(
        self,
        queue_path: Path,
        *,
        limit: int,
        sleep_sec: float,
    ) -> dict[str, int]:
        queue = self._load_queue(queue_path)
        items: list[dict[str, Any]] = list(queue.get("items") or [])
        stats = {
            "ok": 0,
            "failed": 0,
            "quota_stop": 0,
            "remaining_pending": 0,
            "skipped_done": 0,
        }
        processed_this_run = 0

        for item in items:
            status = (item.get("status") or "").strip()
            if status in {"done", "failed_permanent"}:
                stats["skipped_done"] += 1
                continue
            if status == "skipped_quota":
                # Kota sonrası kalanlar — yeniden dene.
                item["status"] = "pending"
                item["error"] = ""

            if limit and processed_this_run >= limit:
                break

            if gemini_quota_cooldown_active():
                rem = int(gemini_quota_cooldown_remaining_sec() + 0.5)
                item["status"] = "skipped_quota"
                item["error"] = f"Gemini kota cooldown (~{rem}s)"
                item["processed_at"] = _utc_now_iso()
                stats["quota_stop"] += 1
                self._mark_remaining_quota(items, item)
                self.stdout.write(
                    self.style.WARNING(
                        f"Kota cooldown aktif — duruluyor (~{rem}s). "
                        "Kalanlar kuyrukta."
                    )
                )
                break

            old_id = item.get("old_public_id") or "?"
            chat_id = int(item["chat_id"])
            message_id = int(item["message_id"])
            self.stdout.write(
                f"> {old_id} chat={chat_id} msg={message_id} ..."
            )
            processed_this_run += 1

            try:
                image_bytes, mime, file_uid, caption, _file_id = _forward_and_download(
                    chat_id, message_id
                )
            except Exception as exc:  # noqa: BLE001
                item["status"] = "failed"
                item["error"] = f"re-fetch: {exc}"
                item["processed_at"] = _utc_now_iso()
                stats["failed"] += 1
                self.stdout.write(self.style.ERROR(f"  FAIL re-fetch: {exc}"))
                self._save_queue(queue_path, queue)
                continue

            if file_uid:
                item["file_unique_id"] = file_uid
            topic_slug, _cap_sol, explicit_topic, archive_label = _parse_photo_caption(
                caption
            )
            if not archive_label:
                # Eski kayıttaki etiket veya kısa caption yedek.
                archive_label = (item.get("osym_cikmis_adi") or "").strip()
                if not archive_label:
                    archive_label = parse_telegram_caption_archive_label(caption)

            topic = _resolve_topic(topic_slug)
            if topic is None:
                item["status"] = "failed"
                item["error"] = "Aktif konu bulunamadı"
                item["processed_at"] = _utc_now_iso()
                stats["failed"] += 1
                self.stdout.write(self.style.ERROR("  FAIL: topic yok"))
                self._save_queue(queue_path, queue)
                continue

            ext = "jpg" if "jpeg" in mime else mime.split("/")[-1]
            filename = f"telegram_re_{message_id}.{ext}"
            buffer = io.BytesIO(image_bytes)

            try:
                result = ingest_question_from_image(
                    buffer,
                    topic=topic,
                    filename=filename,
                    mime=mime,
                    publish=False,
                    submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
                    telegram_chat_id=chat_id,
                    telegram_message_id=message_id,
                    telegram_file_unique_id=(
                        file_uid or item.get("file_unique_id") or ""
                    ),
                    allow_duplicate=True,
                    auto_classify_topic=not explicit_topic,
                )
            except IntegrityError as exc:
                item["status"] = "failed"
                item["error"] = f"IntegrityError: {exc}"
                item["processed_at"] = _utc_now_iso()
                stats["failed"] += 1
                self.stdout.write(self.style.ERROR(f"  FAIL integrity: {exc}"))
                self._save_queue(queue_path, queue)
                continue
            except Exception as exc:  # noqa: BLE001
                err = str(exc)
                if is_gemini_quota_error(err):
                    item["status"] = "skipped_quota"
                    item["error"] = err[:500]
                    item["processed_at"] = _utc_now_iso()
                    stats["quota_stop"] += 1
                    self._mark_remaining_quota(items, item)
                    self.stdout.write(
                        self.style.WARNING(f"  QUOTA — duruluyor: {err[:120]}")
                    )
                    self._save_queue(queue_path, queue)
                    break
                item["status"] = "failed"
                item["error"] = err[:500]
                item["processed_at"] = _utc_now_iso()
                stats["failed"] += 1
                self.stdout.write(self.style.ERROR(f"  FAIL ingest: {err[:200]}"))
                self._save_queue(queue_path, queue)
                continue

            if not result.ok or result.question is None:
                err = result.error or "ingest failed"
                if is_gemini_quota_error(err) or is_gemini_quota_error(
                    result.operator_warning or ""
                ):
                    item["status"] = "skipped_quota"
                    item["error"] = err[:500]
                    item["processed_at"] = _utc_now_iso()
                    stats["quota_stop"] += 1
                    self._mark_remaining_quota(items, item)
                    self.stdout.write(
                        self.style.WARNING(f"  QUOTA — duruluyor: {err[:120]}")
                    )
                    self._save_queue(queue_path, queue)
                    break
                item["status"] = "failed"
                item["error"] = err[:500]
                item["processed_at"] = _utc_now_iso()
                stats["failed"] += 1
                self.stdout.write(self.style.ERROR(f"  FAIL: {err[:200]}"))
                self._save_queue(queue_path, queue)
                continue

            # Kalite kapısı: Tesseract-only / fallback sonuçlarını panele koyma.
            engine = (result.engine or "").strip()
            warn = result.operator_warning or ""
            log = (
                OcrIngestLog.objects.filter(
                    source_image_hash=result.question.source_image_hash or ""
                )
                .order_by("-created_at")
                .first()
            )
            is_fallback = (
                _is_tesseract_engine(engine)
                or (log and log.status == OcrIngestLog.STATUS_FALLBACK_SUCCESS)
                or (log and _is_tesseract_engine(log.engine or ""))
            )
            quota_hit = is_gemini_quota_error(warn) or (
                log and is_gemini_quota_error(log.error_message or "")
            )

            if is_fallback:
                new_pid = result.question.public_id
                result.question.delete()
                if quota_hit:
                    item["status"] = "skipped_quota"
                    item["error"] = (
                        f"Gemini kota; Tesseract çöpü silindi ({new_pid}). "
                        f"{warn or (log.error_message if log else '')}"
                    )[:500]
                    item["processed_at"] = _utc_now_iso()
                    stats["quota_stop"] += 1
                    self._mark_remaining_quota(items, item)
                    self.stdout.write(
                        self.style.WARNING(
                            f"  QUOTA — Tesseract taslak silindi ({new_pid}), "
                            "kalanlar kuyrukta."
                        )
                    )
                    self._save_queue(queue_path, queue)
                    break
                item["status"] = "failed"
                item["error"] = (
                    f"Gemini yok/başarısız; Tesseract taslak silindi ({new_pid}). "
                    f"{warn}"
                )[:500]
                item["processed_at"] = _utc_now_iso()
                stats["failed"] += 1
                self.stdout.write(
                    self.style.ERROR(
                        f"  FAIL quality-gate: Tesseract taslak silindi ({new_pid})"
                    )
                )
                self._save_queue(queue_path, queue)
                continue

            if archive_label:
                _apply_archive_label(result.question, archive_label)
            elif item.get("osym_cikmis_adi"):
                _apply_archive_label(result.question, item["osym_cikmis_adi"])

            item["status"] = "done"
            item["new_public_id"] = result.question.public_id
            item["error"] = ""
            item["processed_at"] = _utc_now_iso()
            stats["ok"] += 1
            self.stdout.write(
                self.style.SUCCESS(
                    f"  OK {result.question.public_id} engine={engine or 'gemini'} "
                    f"correct={result.question.correct_option or '-'} "
                    f"sol_len={len(result.question.solution or '')}"
                )
            )
            self._save_queue(queue_path, queue)
            if sleep_sec > 0:
                time.sleep(sleep_sec)

        stats["remaining_pending"] = sum(
            1
            for i in items
            if (i.get("status") or "") in {"pending", "skipped_quota"}
        )
        queue["updated_at"] = _utc_now_iso()
        self._save_queue(queue_path, queue)
        return stats

    def _mark_remaining_quota(
        self, items: list[dict[str, Any]], current: dict[str, Any]
    ) -> None:
        """Kota kesilince henüz işlenmemişleri skipped_quota yap (özet için)."""
        seen = False
        for item in items:
            if item is current:
                seen = True
                continue
            if not seen:
                continue
            if (item.get("status") or "") == "pending":
                item["status"] = "skipped_quota"
                item["error"] = "Önceki öğede Gemini kota — bekliyor"
                item["processed_at"] = _utc_now_iso()
