"""Instagram Graph API ile soru Reels paylaşımı için bağımsız servis.

Gerekli ortam değişkenleri:
  INSTAGRAM_GRAPH_ACCESS_TOKEN  Uzun ömürlü Page/Instagram erişim jetonu
  INSTAGRAM_GRAPH_IG_USER_ID    Profesyonel Instagram hesabı kimliği
  PUBLIC_BASE_URL                Meta'nın erişebildiği HTTPS site adresi
Opsiyonel:
  INSTAGRAM_GRAPH_API_VERSION    Varsayılan: v22.0

Meta Reels Publishing API, yerel dosya yüklemesini kabul etmez; `video_url`
internet üzerinden erişilebilen HTTPS bir URL olmalıdır. Bu servis MP4'ü
MEDIA_ROOT altında üretir ve PUBLIC_BASE_URL üzerinden bu URL'yi oluşturur.

Yorum sabitleme, Instagram Graph API tarafından desteklenen bir işlem değildir.
Bu nedenle servis yorumu gönderir ama sabitlemeye çalışmaz. client_insights
yalnızca ölçüm endpoint'idir; yorum sabitlemek için kullanılamaz.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
import threading
import time
import uuid
from datetime import timedelta
from pathlib import Path
from textwrap import wrap
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.utils import timezone
from PIL import Image, ImageDraw, ImageFont, ImageOps

from content.models import Question

logger = logging.getLogger(__name__)


class InstagramAutomationError(RuntimeError):
    """Instagram otomasyonu yapılandırma, video veya Graph API hatası."""


class InstagramAutomationService:
    """Yayınlanmış sorulardan Reels üretip Instagram'a gönderen servis."""

    video_size = (1080, 1920)
    video_duration_seconds = 12
    comment_delay = timedelta(hours=1)
    background = "#101A35"
    accent = "#E9C46A"
    _queue_lock = threading.Lock()

    def get_random_question(self) -> Question:
        """Yalnızca mobilde yayımlanmış bir soruyu rastgele seçer."""
        question = (
            Question.objects.filter(is_published=True)
            .select_related("topic", "topic__subject")
            .order_by("?")
            .first()
        )
        if question is None:
            raise InstagramAutomationError("Paylaşılacak yayımlanmış soru bulunamadı.")
        return question

    def generate_reels_video(self, question: Question) -> Path:
        """Soru ve şıklarından geçici, dikey koyu temalı bir MP4 üretir.

        Soru modelinde ayrı bir LaTeX alanı yoktur. Varsa soru görseli
        (`question.image`) videoya eklenir; stem ve şıklar Unicode metin olarak
        çizilir. LaTeX kaynak kodu metnin parçasıysa ayrıca görselleştirilmez.
        """
        output_dir = self._media_dir() / "videos"
        output_dir.mkdir(parents=True, exist_ok=True)
        frame_path = output_dir / f"{question.public_id}-{uuid.uuid4().hex}.png"
        video_path = frame_path.with_suffix(".mp4")

        canvas = Image.new("RGB", self.video_size, self.background)
        draw = ImageDraw.Draw(canvas)
        bold = self._font(50, bold=True)
        body = self._font(39)
        option = self._font(36)

        draw.rounded_rectangle(
            (54, 64, 1026, 176), radius=28, fill="#18284D", outline="#E9C46A", width=2
        )
        draw.text((94, 91), "HEDEF KAMU  •  GÜNÜN SORUSU", font=bold, fill=self.accent)

        y = 235
        subject = f"{question.topic.subject.name} / {question.topic.name}"
        draw.text((72, y), subject.upper()[:52], font=self._font(28), fill="#9FAFD1")
        y += 70
        y = self._draw_wrapped_text(
            draw,
            question.stem,
            x=72,
            y=y,
            font=body,
            fill="#F7F8FC",
            max_chars=42,
            max_lines=9,
            line_height=54,
        )

        if question.image:
            y = self._draw_question_image(canvas, question, y)

        y = max(y + 28, 855)
        for letter, text in question.options_map().items():
            if y > 1640:
                break
            draw.rounded_rectangle(
                (72, y, 1008, y + 100), radius=18, fill="#19284A", outline="#31446E", width=2
            )
            draw.ellipse((92, y + 22, 148, y + 78), fill=self.accent)
            draw.text((108, y + 28), letter, font=self._font(28, bold=True), fill=self.background)
            self._draw_wrapped_text(
                draw,
                text,
                x=172,
                y=y + 24,
                font=option,
                fill="#FFFFFF",
                max_chars=36,
                max_lines=2,
                line_height=38,
            )
            y += 118

        draw.text(
            (72, 1800),
            "Cevabını yorumlara yaz. Doğru cevap 1 saat sonra!",
            font=self._font(29),
            fill="#C9D4EB",
        )
        canvas.save(frame_path, "PNG", optimize=True)

        try:
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-loop",
                    "1",
                    "-i",
                    str(frame_path),
                    "-c:v",
                    "libx264",
                    "-t",
                    str(self.video_duration_seconds),
                    "-pix_fmt",
                    "yuv420p",
                    "-vf",
                    "fps=30",
                    "-movflags",
                    "+faststart",
                    str(video_path),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
        except FileNotFoundError as exc:
            logger.error(
                "[instagram][video] ffmpeg bulunamadı; Reels üretilemedi. question=%s",
                question.public_id,
            )
            raise InstagramAutomationError(
                "Video üretimi için sunucuda ffmpeg kurulu olmalıdır."
            ) from exc
        except subprocess.CalledProcessError as exc:
            logger.error(
                "[instagram][video] ffmpeg başarısız. question=%s stderr=%s",
                question.public_id,
                (exc.stderr or "")[-500:],
            )
            raise InstagramAutomationError(
                f"ffmpeg video üretimi başarısız: {exc.stderr[-500:]}"
            ) from exc
        finally:
            frame_path.unlink(missing_ok=True)

        return video_path

    def publish_reels(self, question: Question | None = None) -> dict[str, str] | None:
        """Reels container oluşturur, hazır olduğunda yayımlar ve yorumu planlar.

        Meta spam/token veya video hatalarında sunucu çökmez; hata logger.error ile
        kayda geçer ve None döner.
        """
        try:
            question = question or self.get_random_question()
            video_path = self.generate_reels_video(question)
            video_url = self._public_url(video_path)
            caption = (
                f"{question.topic.subject.name} • {question.topic.name}\n\n"
                "Şıkkını yorumlara yaz; doğru cevap 1 saat sonra yorumda. 👇\n\n"
                "#kpss #kpss2026 #hedefkamu"
            )
            container = self._post(
                f"/{self._instagram_user_id}/media",
                {
                    "media_type": "REELS",
                    "video_url": video_url,
                    "caption": caption,
                    "share_to_feed": "true",
                },
            )
            if container is None:
                return None
            container_id = container.get("id")
            if not container_id:
                logger.error(
                    "[instagram][meta] /media yanıtında container id yok. body=%s",
                    container,
                )
                return None

            if not self._wait_until_ready(container_id):
                return None
            published = self._post(
                f"/{self._instagram_user_id}/media_publish",
                {"creation_id": container_id},
            )
            if published is None:
                return None
            media_id = published.get("id")
            if not media_id:
                logger.error(
                    "[instagram][meta] /media_publish yanıtında media_id yok. body=%s",
                    published,
                )
                return None

            scheduled_for = self.schedule_answer_comment(
                media_id, question.correct_option
            )
            self._save_publication(
                {
                    "question_id": question.public_id,
                    "media_id": str(media_id),
                    "video_url": video_url,
                    "published_at": timezone.now().isoformat(),
                    "answer_comment_due_at": scheduled_for.isoformat(),
                }
            )
            logger.info(
                "[instagram] Reels yayımlandı. question=%s media_id=%s",
                question.public_id,
                media_id,
            )
            return {"media_id": str(media_id), "video_url": video_url}
        except InstagramAutomationError as exc:
            logger.error("[instagram] Reels paylaşımı başarısız: %s", exc)
            return None
        except Exception as exc:  # noqa: BLE001 — cron/timer sürecini düşürme
            logger.error(
                "[instagram] Beklenmeyen Reels hatası: %s",
                exc,
                exc_info=True,
            )
            return None

    def post_answer_comment(self, media_id: str, correct_answer: str) -> str | None:
        """Doğru cevabı Reels'a yorum olarak gönderir; yorum id'sini döndürür."""
        answer = correct_answer.strip().upper()
        if answer not in {"A", "B", "C", "D", "E"}:
            logger.error(
                "[instagram][meta] Geçersiz doğru cevap: %s (media_id=%s)",
                correct_answer,
                media_id,
            )
            return None

        try:
            response = self._post(
                f"/{media_id}/comments",
                {
                    "message": (
                        f"✅ Doğru cevap: {answer}\n"
                        "Çözüm için Hedef Kamu uygulamasını keşfet!"
                    )
                },
            )
        except InstagramAutomationError as exc:
            logger.error(
                "[instagram][meta] Yorum gönderilemedi media_id=%s: %s",
                media_id,
                exc,
            )
            return None

        if response is None:
            return None
        comment_id = response.get("id")
        if not comment_id:
            logger.error(
                "[instagram][meta] /comments yanıtında id yok. media_id=%s body=%s",
                media_id,
                response,
            )
            return None
        logger.info(
            "Instagram yorum gönderildi (media_id=%s, comment_id=%s). "
            "Yorum sabitleme Graph API tarafından desteklenmiyor.",
            media_id,
            comment_id,
        )
        return str(comment_id)

    def schedule_answer_comment(self, media_id: str, correct_answer: str):
        """Yorumu bir saat sonrası için kalıcı kuyruğa ekler.

        Uygulama süreci ayakta kalırsa daemon timer da işi tetikler. Üretimde,
        süreç yeniden başlatılsa bile bekleyen kayıtlar için bir scheduler
        (cron/Celery) ile `run_due_answer_comments()` çağrılmalıdır.
        """
        due_at = timezone.now() + self.comment_delay
        job = {
            "id": uuid.uuid4().hex,
            "media_id": str(media_id),
            "correct_answer": correct_answer.upper(),
            "due_at": due_at.isoformat(),
        }
        self._append_queue_job(job)
        timer = threading.Timer(
            self.comment_delay.total_seconds(), self.run_due_answer_comments
        )
        timer.daemon = True
        timer.start()
        return due_at

    def run_due_answer_comments(self) -> int:
        """Vadesi gelen kalıcı yorum işlerini çalıştırır; cron için uygundur."""
        completed = 0
        now = timezone.now()
        with self._queue_lock:
            jobs = self._read_json(self._queue_path(), default=[])
            pending = []
            for job in jobs:
                due_at = timezone.datetime.fromisoformat(job["due_at"])
                if due_at > now:
                    pending.append(job)
                    continue
                try:
                    comment_id = self.post_answer_comment(
                        job["media_id"], job["correct_answer"]
                    )
                    if comment_id:
                        completed += 1
                    else:
                        pending.append(job)
                except Exception as exc:  # noqa: BLE001
                    logger.error(
                        "[instagram][meta] Cevap yorumu işi başarısız job=%s: %s",
                        job.get("id"),
                        exc,
                        exc_info=True,
                    )
                    pending.append(job)
            self._write_json(self._queue_path(), pending)
        return completed

    @property
    def _instagram_user_id(self) -> str:
        return self._required_setting("INSTAGRAM_GRAPH_IG_USER_ID")

    @property
    def _access_token(self) -> str:
        return self._required_setting("INSTAGRAM_GRAPH_ACCESS_TOKEN")

    @property
    def _api_base(self) -> str:
        version = os.environ.get("INSTAGRAM_GRAPH_API_VERSION", "v22.0")
        return f"https://graph.facebook.com/{version}"

    def _post(self, path: str, data: dict[str, str]) -> dict[str, Any] | None:
        payload = urlencode({**data, "access_token": self._access_token}).encode()
        request = Request(
            f"{self._api_base}{path}",
            data=payload,
            method="POST",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        return self._request_json(request, path=path)

    def _get(self, path: str, data: dict[str, str]) -> dict[str, Any] | None:
        query = urlencode({**data, "access_token": self._access_token})
        return self._request_json(
            Request(f"{self._api_base}{path}?{query}"),
            path=path,
        )

    def _request_json(
        self, request: Request, *, path: str
    ) -> dict[str, Any] | None:
        """Graph API çağrısı. status_code != 200 ise logger.error yazar, None döner."""
        try:
            with urlopen(request, timeout=30) as response:  # noqa: S310 - Meta HTTPS URL
                status_code = getattr(response, "status", None) or response.getcode()
                body = response.read().decode("utf-8", errors="replace")
                if status_code != 200:
                    logger.error(
                        "[instagram][meta] Graph API başarısız. "
                        "path=%s status_code=%s body=%s",
                        path,
                        status_code,
                        body[:500],
                    )
                    return None
                try:
                    return json.loads(body)
                except json.JSONDecodeError:
                    logger.error(
                        "[instagram][meta] Geçersiz JSON. path=%s status_code=%s body=%s",
                        path,
                        status_code,
                        body[:500],
                    )
                    return None
        except HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            logger.error(
                "[instagram][meta] Graph API HTTP hatası (spam/token/izin). "
                "path=%s status_code=%s body=%s",
                path,
                exc.code,
                detail[:500],
            )
            return None
        except URLError as exc:
            logger.error(
                "[instagram][meta] Graph API erişilemedi. path=%s reason=%s",
                path,
                exc.reason,
            )
            return None

    def _wait_until_ready(self, container_id: str) -> bool:
        for attempt in range(18):
            status = self._get(f"/{container_id}", {"fields": "status_code"})
            if status is None:
                return False
            status_code = status.get("status_code")
            if status_code == "FINISHED":
                return True
            if status_code in {"ERROR", "EXPIRED"}:
                logger.error(
                    "[instagram][meta] Reels container işlenemedi. "
                    "container_id=%s status_code=%s (video_url Meta tarafından "
                    "okunamadı veya format reddedildi olabilir)",
                    container_id,
                    status_code,
                )
                return False
            logger.info(
                "[instagram][meta] Container bekleniyor. container_id=%s "
                "status_code=%s attempt=%s",
                container_id,
                status_code,
                attempt + 1,
            )
            time.sleep(10)
        logger.error(
            "[instagram][meta] Reels container zaman aşımı. container_id=%s",
            container_id,
        )
        return False

    def _media_dir(self) -> Path:
        return Path(settings.MEDIA_ROOT) / "instagram_reels"

    def _queue_path(self) -> Path:
        path = self._media_dir() / "pending_answer_comments.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        return path

    def _publication_path(self) -> Path:
        path = self._media_dir() / "publications.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        return path

    def _public_url(self, video_path: Path) -> str:
        base_url = self._required_setting("PUBLIC_BASE_URL").rstrip("/")
        if not base_url.startswith("https://"):
            raise InstagramAutomationError(
                "PUBLIC_BASE_URL Meta'nın erişebileceği HTTPS bir URL olmalıdır."
            )
        relative = video_path.relative_to(settings.MEDIA_ROOT).as_posix()
        return f"{base_url}{settings.MEDIA_URL}{relative}"

    def _append_queue_job(self, job: dict[str, str]) -> None:
        with self._queue_lock:
            jobs = self._read_json(self._queue_path(), default=[])
            jobs.append(job)
            self._write_json(self._queue_path(), jobs)

    def _save_publication(self, publication: dict[str, str]) -> None:
        path = self._publication_path()
        with self._queue_lock:
            publications = self._read_json(path, default=[])
            publications.append(publication)
            self._write_json(path, publications)

    @staticmethod
    def _read_json(path: Path, *, default: list[dict[str, str]]) -> list[dict[str, str]]:
        if not path.exists():
            return default
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            logger.exception("Instagram kuyruk kaydı okunamadı: %s", path)
            return default

    @staticmethod
    def _write_json(path: Path, data: list[dict[str, str]]) -> None:
        temporary = path.with_suffix(".tmp")
        temporary.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        temporary.replace(path)

    def _font(self, size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
        candidates = (
            ("C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/arial.ttf")
            if bold
            else ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/Arial.ttf")
        )
        for candidate in candidates:
            if Path(candidate).exists():
                return ImageFont.truetype(candidate, size)
        return ImageFont.load_default()

    def _draw_wrapped_text(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        *,
        x: int,
        y: int,
        font: ImageFont.ImageFont,
        fill: str,
        max_chars: int,
        max_lines: int,
        line_height: int,
    ) -> int:
        lines = wrap(" ".join((text or "").split()), width=max_chars) or ["—"]
        for line in lines[:max_lines]:
            draw.text((x, y), line, font=font, fill=fill)
            y += line_height
        return y

    def _draw_question_image(self, canvas: Image.Image, question: Question, y: int) -> int:
        try:
            with question.image.open("rb") as source:
                image = Image.open(source).convert("RGB")
                image.thumbnail((860, 380))
                image = ImageOps.contain(image, (860, 380))
                x = (self.video_size[0] - image.width) // 2
                canvas.paste(image, (x, y))
                return y + image.height
        except OSError:
            logger.warning("Soru görseli Reels'a eklenemedi: %s", question.public_id)
            return y

    @staticmethod
    def _required_setting(name: str) -> str:
        value = os.environ.get(name, "").strip()
        if not value:
            raise InstagramAutomationError(f"{name} ortam değişkeni tanımlı değil.")
        return value
