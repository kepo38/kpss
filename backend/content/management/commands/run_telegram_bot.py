import json
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request

from django.conf import settings
from django.core.management.base import BaseCommand

from content.telegram_bot import (
    DrainStats,
    TelegramBotLockError,
    drain_error_summary,
    drain_error_footer,
    ensure_polling_mode,
    get_webhook_info,
    handle_update,
    notify_drain_complete,
    peek_update_queue,
    register_bot_commands,
    set_webhook,
    telegram_configured,
    telegram_lock,
)
from content.panel_context import pending_telegram_question_count


def _ssl_context() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    try:
        import certifi

        ctx.load_verify_locations(certifi.where())
    except ImportError:
        pass
    return ctx


def _fetch_updates(token: str, offset: int, *, timeout: int) -> list[dict]:
    allowed = urllib.parse.quote(
        json.dumps(["message", "edited_message", "callback_query"])
    )
    api = (
        f"https://api.telegram.org/bot{token}/getUpdates"
        f"?timeout={timeout}&offset={offset}&allowed_updates={allowed}"
    )
    with urllib.request.urlopen(
        api, timeout=max(timeout + 5, 10), context=_ssl_context()
    ) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data.get("result", [])


class Command(BaseCommand):
    help = (
        "Telegram bot: kuyruk aktarımı (varsayılan) veya sürekli dinleme (--watch)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--set-webhook",
            metavar="PUBLIC_URL",
            help="Webhook kur (örn. https://alanadiniz.com)",
        )
        parser.add_argument(
            "--watch",
            action="store_true",
            help="Sürekli dinle (Ctrl+C ile dur). Varsayılan: kuyruğu boşalt ve çık.",
        )
        parser.add_argument(
            "--diagnose",
            action="store_true",
            help="Webhook / kuyruk / panel özeti; mesaj işlemeden çık.",
        )

    def handle(self, *args, **options):
        if not telegram_configured():
            self.stderr.write(
                self.style.ERROR("TELEGRAM_BOT_TOKEN tanımlı değil.")
            )
            return

        if options.get("diagnose"):
            self._run_diagnose()
            return

        if options.get("set_webhook"):
            secret = getattr(settings, "TELEGRAM_WEBHOOK_SECRET", "") or ""
            if not secret:
                self.stderr.write(
                    self.style.ERROR("TELEGRAM_WEBHOOK_SECRET tanımlı değil.")
                )
                return
            url = set_webhook(options["set_webhook"], secret)
            self.stdout.write(self.style.SUCCESS(f"Webhook kuruldu: {url}"))
            return

        token = settings.TELEGRAM_BOT_TOKEN
        try:
            with telegram_lock():
                if options.get("watch"):
                    self._run_watch(token)
                else:
                    self._run_drain(token)
        except TelegramBotLockError as exc:
            self.stderr.write(self.style.ERROR(str(exc)))
            raise SystemExit(2) from exc

    def _prepare_polling(self) -> None:
        cleared = ensure_polling_mode()
        if cleared:
            self.stdout.write(
                self.style.WARNING(
                    f"Webhook kapatıldı (yerel aktarım için): {cleared}"
                )
            )
        register_bot_commands()

    def _run_diagnose(self) -> None:
        wh = get_webhook_info()
        wh_url = (wh.get("url") or "").strip()
        total, photos = peek_update_queue()
        pending = pending_telegram_question_count()
        allowed = getattr(settings, "TELEGRAM_ALLOWED_USER_IDS", []) or []

        self.stdout.write("=== Telegram tanı ===")
        self.stdout.write(f"Panel onay bekleyen: {pending}")
        self.stdout.write(
            f"Webhook: {wh_url or '(yok — polling uygun)'}"
        )
        if wh_url:
            self.stdout.write(
                self.style.WARNING(
                    "Webhook açıkken TELEGRAM.bat mesaj alamaz; "
                    "aktarım başlarken otomatik kapatılır."
                )
            )
        self.stdout.write(
            f"Telegram kuyruk (getUpdates): {photos} fotoğraf / {total} mesaj"
        )
        self.stdout.write(
            f"Yetkili kullanıcı ID: {', '.join(str(x) for x in allowed) or '(yok!)'}"
        )
        if not allowed:
            self.stdout.write(
                self.style.ERROR(
                    "TELEGRAM_ALLOWED_USER_IDS boş — bot kimseye cevap vermez."
                )
            )
        self.stdout.write("")
        self.stdout.write(
            "Evde sürekli dinleme: TELEGRAM-WATCH.bat\n"
            "Tek seferlik aktarım: TELEGRAM.bat"
        )

    def _process_batch(
        self,
        batch: list[dict],
        offset: int,
        stats: DrainStats | None,
        *,
        advance_on_error: bool = False,
    ) -> tuple[int, int, bool]:
        """Offset yalnizca basarili/atlanan mesajlarda ilerler; hatada kalir."""
        processed = 0
        for update in batch:
            try:
                outcome = handle_update(update)
            except Exception as exc:  # noqa: BLE001
                if stats is not None:
                    stats.errors += 1
                self.stderr.write(f"Mesaj işlenemedi: {exc}")
                if advance_on_error:
                    offset = update["update_id"] + 1
                    continue
                return offset, processed, True
            if outcome == "error":
                if stats is not None:
                    stats.errors += 1
                if advance_on_error:
                    offset = update["update_id"] + 1
                    continue
                return offset, processed, True
            if stats is not None:
                stats.record(outcome)
            processed += 1
            offset = update["update_id"] + 1
        return offset, processed, False

    def _run_drain(self, token: str) -> None:
        self._prepare_polling()
        offset = 0
        stats = DrainStats()

        self.stdout.write(
            "Telegram kuyruğu kontrol ediliyor…\n"
            "• Son 24 saat: otomatik işlenir.\n"
            "• Daha eski fotoğraflar: sohbette kalır — İlet (forward) ile gönderin.\n"
            "• Hata olursa mesaj kuyrukta kalır — TELEGRAM.bat tekrar deneyin.\n"
            "• Panel: Onay bekleyen sorular"
        )

        stopped_on_error = False
        while True:
            try:
                batch = _fetch_updates(token, offset, timeout=0)
            except (urllib.error.URLError, TimeoutError) as exc:
                self.stderr.write(f"Telegram bağlantı hatası: {exc}")
                time.sleep(2)
                continue

            if not batch:
                break

            self.stdout.write(f"{len(batch)} bekleyen mesaj işleniyor…")
            offset, processed, stopped_on_error = self._process_batch(
                batch, offset, stats
            )
            if stopped_on_error:
                self.stdout.write(
                    self.style.WARNING(
                        f"{processed} mesaj işlendi; hatalı mesaj kuyrukta kaldı."
                    )
                )
                break
            self.stdout.write(
                self.style.SUCCESS(f"{processed} mesaj işlendi.")
            )

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS("=== Aktarım tamamlandı ==="))
        self.stdout.write(f"Yeni soru: {stats.ingested}")
        if stats.skipped:
            self.stdout.write(f"Zaten kayıtlı (atlandı): {stats.skipped}")
        if stats.errors:
            self.stdout.write(self.style.WARNING(drain_error_summary(stats.errors)))
            self.stdout.write(drain_error_footer())
        if stats.commands:
            self.stdout.write(f"Komut/yardım: {stats.commands}")
        if stats.ingested == 0 and stats.skipped == 0 and stats.errors == 0:
            self.stdout.write(
                "Telegram kuyruğunda işlenecek fotoğraf kalmadı."
            )
        elif stats.errors:
            pass
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    "Telegram kuyruğu boş — bekleyen soru kalmadı."
                )
            )
        self.stdout.write("")
        self.stdout.write("Telegram sohbetinize de özet gönderildi.")
        self.stdout.write("Bu pencereyi kapatabilirsiniz.")

        notify_drain_complete(stats)

    def _run_watch(self, token: str) -> None:
        self._prepare_polling()
        offset = 0
        self.stdout.write(
            self.style.SUCCESS(
                "Bot sürekli dinliyor (--watch).\n"
                "• Son 24 saat: otomatik işlenir.\n"
                "• Daha eski fotoğraflar: İlet (forward) ile gönderin.\n"
                "• Hata olursa mesaj kuyrukta kalır, otomatik yeniden denenir.\n"
                "• Durdurmak: Ctrl+C"
            )
        )
        while True:
            try:
                batch = _fetch_updates(token, offset, timeout=30)
            except (urllib.error.URLError, TimeoutError):
                time.sleep(2)
                continue
            if batch:
                self.stdout.write(f"{len(batch)} bekleyen mesaj işleniyor…")
                offset, processed, stopped_on_error = self._process_batch(
                    batch, offset, None, advance_on_error=True
                )
                if stopped_on_error:
                    self.stdout.write(
                        self.style.WARNING(
                            f"{processed} mesaj işlendi; hatalı mesaj tekrar denenecek."
                        )
                    )
                else:
                    self.stdout.write(
                        self.style.SUCCESS(f"{processed} mesaj tamam.")
                    )
