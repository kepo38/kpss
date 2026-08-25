"""Telegram bot çok adımlı konuşma — çözüm yapıştırma akışı."""

from __future__ import annotations

import re
from dataclasses import dataclass

from .embeddings import refresh_question_embedding
from .models import Question, TelegramBotSession, TelegramPendingSolution
from .rich_text_telegram import normalize_telegram_solution

_YES = frozenset({"evet", "e", "yes", "y"})
_NO = frozenset({"hayır", "hayir", "h", "no", "n"})

# Google çözümleri uzun; kısa onay sözcükleri çözüm sayılmaz.
_SOLUTION_TEXT_MIN_LEN = 40

CALLBACK_SOLUTION_YES = "sol_yes"
CALLBACK_SOLUTION_NO = "sol_no"
CALLBACK_PHOTO_YES_PREFIX = f"{CALLBACK_SOLUTION_YES}:m:"
CALLBACK_PHOTO_NO_PREFIX = f"{CALLBACK_SOLUTION_NO}:m:"


def looks_like_solution_text(text: str) -> bool:
    """Evet/Hayır değil; Google'dan yapıştırılmış çözüm."""
    raw = (text or "").strip()
    if not raw or raw.startswith("/"):
        return False
    lowered = raw.lower()
    if lowered in _YES or lowered in _NO:
        return False
    if len(raw) >= _SOLUTION_TEXT_MIN_LEN:
        return True
    if "\n" in raw or "**" in raw:
        return True
    if re.search(r"[A-E]\)", raw):
        return True
    return False


@dataclass(frozen=True)
class ConversationReply:
    text: str
    delete_photo_message_id: int | None = None


@dataclass(frozen=True)
class OcrIntakeOutcome:
    """OCR bitince Evet/Hayır tekrar edilsin mi, yoksa çözüm zaten bağlandı mı."""

    include_solution_prompt: bool
    reply: ConversationReply | None = None


def start_solution_prompt(
    telegram_user_id: int,
    chat_id: int,
    question: Question,
    *,
    source_message_id: int | None = None,
) -> None:
    """Her soru için ayrı oturum — PC kapalıyken biriken fotoğraflar birbirini ezmesin."""
    TelegramBotSession.objects.update_or_create(
        question=question,
        defaults={
            "telegram_user_id": telegram_user_id,
            "chat_id": chat_id,
            "step": TelegramBotSession.STEP_SOLUTION_YES_NO,
            "source_message_id": source_message_id,
        },
    )


def clear_session(
    telegram_user_id: int,
    *,
    question: Question | None = None,
) -> None:
    qs = TelegramBotSession.objects.filter(telegram_user_id=telegram_user_id)
    if question is not None:
        qs = qs.filter(question=question)
    qs.delete()


def get_session(
    telegram_user_id: int,
    *,
    public_id: str | None = None,
) -> TelegramBotSession | None:
    qs = (
        TelegramBotSession.objects.filter(telegram_user_id=telegram_user_id)
        .select_related("question")
        .order_by("-updated_at")
    )
    if public_id:
        qs = qs.filter(question__public_id=public_id)
    return qs.first()


def solution_prompt_message() -> str:
    return (
        "Çözüm eklemek ister misiniz?\n"
        "Sıradaki soru fotoğrafını şimdi gönderebilirsiniz — "
        "OCR veya Evet/Hayır beklemeyin.\n"
        "Çözüm: fotoğrafın alt yazısı, hemen sonraki mesaj, "
        "veya fotoğrafa yanıt. Evet düğmesi şart değil.\n"
        "Hayır: çözüm yok, OCR bitince panele düşer.\n\n"
        "PC kapalıyken de aynı: fotoğraf + alt yazı veya altındaki "
        "çözüm mesajı. Bot açılınca bağlanır."
    )


def _upsert_photo_intake(
    *,
    telegram_user_id: int,
    chat_id: int,
    photo_message_id: int,
    **fields,
) -> TelegramPendingSolution:
    pending, _created = TelegramPendingSolution.objects.update_or_create(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
        defaults={"telegram_user_id": telegram_user_id, **fields},
    )
    return pending


def save_pending_solution_reply(
    *,
    telegram_user_id: int,
    chat_id: int,
    photo_message_id: int,
    solution_text: str,
) -> None:
    text = (solution_text or "").strip()
    if not text:
        return
    _upsert_photo_intake(
        telegram_user_id=telegram_user_id,
        chat_id=chat_id,
        photo_message_id=photo_message_id,
        solution_text=text,
        skip_solution=False,
        awaiting_text=False,
    )


def mark_photo_prompt_sent(
    *,
    telegram_user_id: int,
    chat_id: int,
    photo_message_id: int,
) -> None:
    pending = TelegramPendingSolution.objects.filter(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
    ).first()
    if pending is None:
        _upsert_photo_intake(
            telegram_user_id=telegram_user_id,
            chat_id=chat_id,
            photo_message_id=photo_message_id,
            solution_text="",
            prompt_sent=True,
        )
        return
    if not pending.prompt_sent:
        pending.prompt_sent = True
        pending.save(update_fields=["prompt_sent"])


def photo_has_solution_ready(*, chat_id: int, photo_message_id: int) -> bool:
    pending = TelegramPendingSolution.objects.filter(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
    ).first()
    if pending is None:
        return False
    return bool(pending.solution_text.strip()) or pending.skip_solution


def pop_pending_solution(
    *,
    chat_id: int,
    photo_message_id: int,
) -> str | None:
    pending = TelegramPendingSolution.objects.filter(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
    ).first()
    if pending is None:
        return None
    text = (pending.solution_text or "").strip()
    pending.delete()
    return text or None


def apply_solution_and_release(
    question: Question,
    solution_text: str,
    *,
    telegram_user_id: int | None = None,
) -> ConversationReply:
    """Çözümü kaydet, onay oturumunu kapat — soru panele düşer."""
    solution = normalize_telegram_solution(solution_text)
    question.solution = solution
    question.save(update_fields=["solution"])
    refresh_question_embedding(question)
    if telegram_user_id is not None:
        clear_session(telegram_user_id, question=question)
    else:
        TelegramBotSession.objects.filter(question=question).delete()
    return ConversationReply(
        "Çözüm kaydedildi.\n"
        f"Kimlik: {question.public_id}\n"
        "Panel → Onay bekleyen sorular → İncele → çözüm alanında görünür."
    )


def try_attach_solution_reply(
    *,
    telegram_user_id: int,
    chat_id: int,
    photo_message_id: int,
    text: str,
    entities: list[dict] | None = None,
) -> ConversationReply | None:
    """Fotoğrafa yanıt olarak gelen çözümü bağla (oturum veya bekleyen kuyruk)."""
    solution = normalize_telegram_solution(text, entities=entities)
    if not solution:
        return ConversationReply(
            "Boş çözüm — fotoğrafa yanıt olarak çözüm metnini yapıştırın."
        )

    session = (
        TelegramBotSession.objects.filter(
            telegram_user_id=telegram_user_id,
            source_message_id=photo_message_id,
        )
        .select_related("question")
        .first()
    )
    if session is not None and session.question_id:
        return apply_solution_and_release(
            session.question,
            solution,
            telegram_user_id=telegram_user_id,
        )

    question = (
        Question.objects.filter(
            telegram_chat_id=chat_id,
            telegram_message_id=photo_message_id,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
            is_published=False,
        )
        .order_by("-id")
        .first()
    )
    if question is not None:
        return apply_solution_and_release(
            question,
            solution,
            telegram_user_id=telegram_user_id,
        )

    # OCR henüz bitmedi veya PC kapalıydı — çözüm kuyruğa alınır.
    save_pending_solution_reply(
        telegram_user_id=telegram_user_id,
        chat_id=chat_id,
        photo_message_id=photo_message_id,
        solution_text=solution,
    )
    return ConversationReply(
        "Çözüm not edildi — fotoğrafa yanıt şart değil.\n"
        "OCR bitince otomatik eklenecek; Evet/Hayır gerekmez.\n"
        "Sıradaki soru fotoğrafını şimdi gönderebilirsiniz."
    )


def try_attach_orphan_solution_text(
    *,
    telegram_user_id: int,
    chat_id: int,
    text: str,
    entities: list[dict] | None = None,
) -> ConversationReply | None:
    """Fotoğrafın hemen altındaki mesaj (yanıt/alt yazı değil) = o fotoğrafın çözümü.

    Telefonda kullanıcı çoğu zaman altyazı yerine sonraki mesajı yazar.
    """
    if not looks_like_solution_text(text):
        return None

    pending = (
        TelegramPendingSolution.objects.filter(
            telegram_user_id=telegram_user_id,
            chat_id=chat_id,
            skip_solution=False,
            solution_text="",
        )
        .order_by("-created_at", "-id")
        .first()
    )
    if pending is not None:
        return try_attach_solution_reply(
            telegram_user_id=telegram_user_id,
            chat_id=chat_id,
            photo_message_id=pending.photo_message_id,
            text=text,
            entities=entities,
        )

    session = (
        TelegramBotSession.objects.filter(telegram_user_id=telegram_user_id)
        .select_related("question")
        .order_by("-updated_at")
        .first()
    )
    if (
        session is not None
        and session.source_message_id
        and not (session.question.solution or "").strip()
    ):
        return try_attach_solution_reply(
            telegram_user_id=telegram_user_id,
            chat_id=chat_id,
            photo_message_id=int(session.source_message_id),
            text=text,
            entities=entities,
        )

    question = (
        Question.objects.filter(
            telegram_chat_id=chat_id,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
            is_published=False,
        )
        .filter(solution="")
        .exclude(telegram_message_id__isnull=True)
        .order_by("-id")
        .first()
    )
    if question is not None and question.telegram_message_id:
        return try_attach_solution_reply(
            telegram_user_id=telegram_user_id,
            chat_id=chat_id,
            photo_message_id=int(question.telegram_message_id),
            text=text,
            entities=entities,
        )
    return None


def handle_photo_solution_decision(
    *,
    telegram_user_id: int,
    chat_id: int,
    photo_message_id: int,
    yes: bool,
) -> ConversationReply:
    """OCR öncesi veya sonrası — fotoğraf mesajına bağlı Evet/Hayır."""
    question = (
        Question.objects.filter(
            telegram_chat_id=chat_id,
            telegram_message_id=photo_message_id,
            submission_source=Question.SUBMISSION_SOURCE_TELEGRAM,
        )
        .order_by("-id")
        .first()
    )
    if yes:
        if question is not None:
            start_solution_prompt(
                telegram_user_id,
                chat_id,
                question,
                source_message_id=photo_message_id,
            )
            session = get_session(telegram_user_id, public_id=question.public_id)
            if session is not None:
                session.step = TelegramBotSession.STEP_SOLUTION_TEXT
                session.save(update_fields=["step", "updated_at"])
        else:
            _upsert_photo_intake(
                telegram_user_id=telegram_user_id,
                chat_id=chat_id,
                photo_message_id=photo_message_id,
                skip_solution=False,
                awaiting_text=True,
                prompt_sent=True,
            )
        return ConversationReply(
            "Çözümü hemen sonraki mesaj olarak yapıştırın "
            "(yanıt veya alt yazı da olur; Google metnini tek seferde).\n"
            "Sıradaki soru fotoğrafını şimdi gönderebilirsiniz — OCR beklemeyin."
        )

    if question is not None:
        clear_session(telegram_user_id, question=question)
        TelegramPendingSolution.objects.filter(
            chat_id=chat_id,
            photo_message_id=photo_message_id,
        ).delete()
        public = question.public_id
        remaining = TelegramBotSession.objects.filter(
            telegram_user_id=telegram_user_id
        ).count()
        extra = (
            f"\nBekleyen onay: {remaining} soru daha."
            if remaining
            else ""
        )
        return ConversationReply(
            f"Tamam — {public} panele düşecek (çözüm yok).\n"
            "Sıradaki soru fotoğrafını şimdi gönderebilirsiniz."
            + extra
        )

    _upsert_photo_intake(
        telegram_user_id=telegram_user_id,
        chat_id=chat_id,
        photo_message_id=photo_message_id,
        solution_text="",
        skip_solution=True,
        awaiting_text=False,
        prompt_sent=True,
    )
    return ConversationReply(
        "Tamam — çözüm yok. OCR bitince panele düşer.\n"
        "Sıradaki soru fotoğrafını şimdi gönderebilirsiniz."
    )


def resolve_photo_intake_after_ocr(
    question: Question,
    *,
    chat_id: int,
    photo_message_id: int,
    telegram_user_id: int,
) -> OcrIntakeOutcome:
    pending = TelegramPendingSolution.objects.filter(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
    ).first()
    if pending is not None and (pending.solution_text or "").strip():
        text = pending.solution_text.strip()
        pending.delete()
        return OcrIntakeOutcome(
            include_solution_prompt=False,
            reply=apply_solution_and_release(
                question,
                text,
                telegram_user_id=telegram_user_id,
            ),
        )
    if pending is not None and pending.skip_solution:
        pending.delete()
        clear_session(telegram_user_id, question=question)
        return OcrIntakeOutcome(include_solution_prompt=False)
    if pending is not None and pending.awaiting_text:
        start_solution_prompt(
            telegram_user_id,
            chat_id,
            question,
            source_message_id=photo_message_id,
        )
        session = get_session(telegram_user_id, public_id=question.public_id)
        if session is not None:
            session.step = TelegramBotSession.STEP_SOLUTION_TEXT
            session.save(update_fields=["step", "updated_at"])
        return OcrIntakeOutcome(include_solution_prompt=False)
    if pending is not None and pending.prompt_sent:
        start_solution_prompt(
            telegram_user_id,
            chat_id,
            question,
            source_message_id=photo_message_id,
        )
        return OcrIntakeOutcome(include_solution_prompt=False)

    start_solution_prompt(
        telegram_user_id,
        chat_id,
        question,
        source_message_id=photo_message_id,
    )
    return OcrIntakeOutcome(include_solution_prompt=True)


def consume_pending_solution_for_question(
    question: Question,
    *,
    chat_id: int,
    photo_message_id: int,
    telegram_user_id: int,
) -> ConversationReply | None:
    """OCR sonrası bekleyen yanıt çözümü varsa uygula; yoksa None."""
    outcome = resolve_photo_intake_after_ocr(
        question,
        chat_id=chat_id,
        photo_message_id=photo_message_id,
        telegram_user_id=telegram_user_id,
    )
    return outcome.reply


def solution_prompt_keyboard(question: Question | None = None) -> dict[str, list[list[dict[str, str]]]]:
    yes = CALLBACK_SOLUTION_YES
    no = CALLBACK_SOLUTION_NO
    if question is not None and question.public_id:
        yes = f"{CALLBACK_SOLUTION_YES}:{question.public_id}"
        no = f"{CALLBACK_SOLUTION_NO}:{question.public_id}"
    return {
        "inline_keyboard": [
            [
                {"text": "Evet", "callback_data": yes},
                {"text": "Hayır", "callback_data": no},
            ]
        ]
    }


def photo_solution_keyboard(photo_message_id: int) -> dict[str, list[list[dict[str, str]]]]:
    mid = int(photo_message_id)
    return {
        "inline_keyboard": [
            [
                {"text": "Evet", "callback_data": f"{CALLBACK_PHOTO_YES_PREFIX}{mid}"},
                {"text": "Hayır", "callback_data": f"{CALLBACK_PHOTO_NO_PREFIX}{mid}"},
            ]
        ]
    }


def _parse_solution_callback(callback_data: str) -> tuple[str, str | None] | None:
    """('evet'|'hayır', public_id|None) veya None. Fotoğraf m: id ayrı işlenir."""
    data = (callback_data or "").strip()
    if data.startswith(CALLBACK_PHOTO_YES_PREFIX) or data.startswith(
        CALLBACK_PHOTO_NO_PREFIX
    ):
        return None
    if data == CALLBACK_SOLUTION_YES or data.startswith(f"{CALLBACK_SOLUTION_YES}:"):
        public_id = data.split(":", 1)[1] if ":" in data else None
        return ("evet", public_id or None)
    if data == CALLBACK_SOLUTION_NO or data.startswith(f"{CALLBACK_SOLUTION_NO}:"):
        public_id = data.split(":", 1)[1] if ":" in data else None
        return ("hayır", public_id or None)
    return None


def try_handle_conversation_callback(
    callback_data: str,
    telegram_user_id: int,
    *,
    chat_id: int | None = None,
) -> ConversationReply | None:
    data = (callback_data or "").strip()
    if chat_id is not None and (
        data.startswith(CALLBACK_PHOTO_YES_PREFIX)
        or data.startswith(CALLBACK_PHOTO_NO_PREFIX)
    ):
        try:
            photo_mid = int(data.rsplit(":", 1)[1])
        except (TypeError, ValueError):
            return None
        return handle_photo_solution_decision(
            telegram_user_id=telegram_user_id,
            chat_id=int(chat_id),
            photo_message_id=photo_mid,
            yes=data.startswith(CALLBACK_PHOTO_YES_PREFIX),
        )
    parsed = _parse_solution_callback(data)
    if parsed is None:
        return None
    answer, public_id = parsed
    return try_handle_conversation(
        telegram_user_id,
        answer,
        public_id=public_id,
    )


def try_handle_conversation(
    telegram_user_id: int,
    text: str,
    *,
    cancel: bool = False,
    entities: list[dict] | None = None,
    public_id: str | None = None,
) -> ConversationReply | None:
    if cancel:
        session = get_session(telegram_user_id, public_id=public_id)
        if session is None:
            return None
        photo_message_id = session.source_message_id
        question = session.question
        discarded = False
        if (
            question is not None
            and not question.is_published
            and question.submission_source == Question.SUBMISSION_SOURCE_TELEGRAM
        ):
            question.delete()
            discarded = True
        else:
            clear_session(telegram_user_id, question=question)
        if discarded:
            return ConversationReply(
                "İptal edildi.\n"
                "Fotoğraf silindi; soru sunucuya / panele gönderilmedi.",
                delete_photo_message_id=photo_message_id,
            )
        return ConversationReply(
            "Çözüm adımı iptal edildi.",
            delete_photo_message_id=photo_message_id,
        )

    normalized = text.strip().lower()
    wants_yes_no = normalized in _YES or normalized in _NO

    if public_id:
        session = get_session(telegram_user_id, public_id=public_id)
    elif wants_yes_no:
        session = (
            TelegramBotSession.objects.filter(
                telegram_user_id=telegram_user_id,
                step=TelegramBotSession.STEP_SOLUTION_YES_NO,
            )
            .select_related("question")
            .order_by("-updated_at")
            .first()
        ) or get_session(telegram_user_id)
    else:
        text_qs = TelegramBotSession.objects.filter(
            telegram_user_id=telegram_user_id,
            step=TelegramBotSession.STEP_SOLUTION_TEXT,
        ).select_related("question")
        n = text_qs.count()
        if n > 1:
            return ConversationReply(
                "Birden fazla soru çözüm bekliyor.\n"
                "Çözümü ilgili FOTOĞRAFA yanıt olarak yapıştırın.\n"
                "Yeni soru fotoğrafını bekletmeden gönderebilirsiniz."
            )
        session = text_qs.first()
        if session is None:
            yes_no_qs = TelegramBotSession.objects.filter(
                telegram_user_id=telegram_user_id,
                step=TelegramBotSession.STEP_SOLUTION_YES_NO,
            ).select_related("question")
            if looks_like_solution_text(text) and yes_no_qs.exists():
                session = yes_no_qs.order_by("-updated_at").first()
            elif yes_no_qs.exists():
                return ConversationReply(
                    "Çözümü hemen sonraki mesaj olarak yapıştırın "
                    "(Evet düğmesi şart değil).\n"
                    "Sıradaki soru fotoğrafını bekletmeden gönderebilirsiniz."
                )
            else:
                return None

    if session is None:
        return None

    if session.step == TelegramBotSession.STEP_SOLUTION_YES_NO:
        if looks_like_solution_text(text):
            return apply_solution_and_release(
                session.question,
                text,
                telegram_user_id=telegram_user_id,
            )
        if normalized in _YES:
            session.step = TelegramBotSession.STEP_SOLUTION_TEXT
            session.save(update_fields=["step", "updated_at"])
            return ConversationReply(
                "Çözümü hemen sonraki mesaj olarak yapıştırın "
                "(fotoğrafa yanıt şart değil).\n"
                f"Soru: {session.question.public_id}\n"
                "Sıradaki soru fotoğrafını şimdi gönderebilirsiniz.\n"
                "İptal: /iptal",
            )
        if normalized in _NO:
            public = session.question.public_id
            clear_session(telegram_user_id, question=session.question)
            remaining = TelegramBotSession.objects.filter(
                telegram_user_id=telegram_user_id
            ).count()
            extra = (
                f"\nBekleyen onay: {remaining} soru daha "
                "(her birinin kendi Evet/Hayır düğmesi var)."
                if remaining
                else ""
            )
            return ConversationReply(
                f"Tamam — {public} panele gönderildi (onay bekliyor).\n"
                "Çözümü panelden istediğiniz zaman ekleyebilirsiniz."
                + extra
            )
        return ConversationReply(
            "Çözümü yapıştırın veya Hayır'a basın.\n"
            "Sıradaki soru fotoğrafını bekletmeden gönderebilirsiniz (iptal: /iptal)."
        )

    if session.step == TelegramBotSession.STEP_SOLUTION_TEXT:
        solution = normalize_telegram_solution(text, entities=entities)
        if not solution:
            return ConversationReply(
                "Boş metin — çözümü yapıştırın veya /iptal ile vazgeçin."
            )
        question = session.question
        question.solution = solution
        question.save(update_fields=["solution"])
        refresh_question_embedding(question)
        clear_session(telegram_user_id, question=question)
        return ConversationReply(
            "Çözüm kaydedildi.\n"
            f"Kimlik: {question.public_id}\n"
            "Panel → Onay bekleyen sorular → İncele → çözüm alanında görünür."
        )

    clear_session(telegram_user_id, question=session.question)
    return None
