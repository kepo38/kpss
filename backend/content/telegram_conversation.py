"""Telegram bot çok adımlı konuşma — çözüm yapıştırma akışı."""

from __future__ import annotations

from dataclasses import dataclass

from .embeddings import refresh_question_embedding
from .models import Question, TelegramBotSession, TelegramPendingSolution
from .rich_text_telegram import normalize_telegram_solution

_YES = frozenset({"evet", "e", "yes", "y"})
_NO = frozenset({"hayır", "hayir", "h", "no", "n"})

CALLBACK_SOLUTION_YES = "sol_yes"
CALLBACK_SOLUTION_NO = "sol_no"


@dataclass(frozen=True)
class ConversationReply:
    text: str
    delete_photo_message_id: int | None = None


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
        "(Google'dan kopyalayıp yapıştırabilirsiniz — paneldeki çözüm "
        "alanına yazılır.)\n"
        "Evet veya Hayır'a basmadan soru panele düşmez.\n"
        "Aşağıdaki düğmelerden seçin.\n\n"
        "PC kapalıyken: fotoğrafa YANIT olarak çözümü yazın; bot açılınca "
        "otomatik eklenir (Evet/Hayır gerekmez)."
    )


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
    TelegramPendingSolution.objects.update_or_create(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
        defaults={
            "telegram_user_id": telegram_user_id,
            "solution_text": text,
        },
    )


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
        "Çözüm not edildi.\n"
        "Fotoğraf işlenince otomatik eklenecek; Evet/Hayır beklemenize gerek yok.\n"
        "Sıradaki soru fotoğrafını gönderebilirsiniz."
    )


def consume_pending_solution_for_question(
    question: Question,
    *,
    chat_id: int,
    photo_message_id: int,
    telegram_user_id: int,
) -> ConversationReply | None:
    """OCR sonrası bekleyen yanıt çözümü varsa uygula; yoksa None."""
    pending = pop_pending_solution(
        chat_id=chat_id,
        photo_message_id=photo_message_id,
    )
    if not pending:
        return None
    return apply_solution_and_release(
        question,
        pending,
        telegram_user_id=telegram_user_id,
    )


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


def _parse_solution_callback(callback_data: str) -> tuple[str, str | None] | None:
    """('evet'|'hayır', public_id|None) veya None."""
    data = (callback_data or "").strip()
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
) -> ConversationReply | None:
    parsed = _parse_solution_callback(callback_data)
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
    session = get_session(telegram_user_id, public_id=public_id)
    if session is None:
        return None

    if cancel:
        photo_message_id = session.source_message_id
        question = session.question
        # Taslak Telegram sorusunu sil — panele düşmesin.
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

    if session.step == TelegramBotSession.STEP_SOLUTION_YES_NO:
        if normalized in _YES:
            session.step = TelegramBotSession.STEP_SOLUTION_TEXT
            session.save(update_fields=["step", "updated_at"])
            return ConversationReply(
                "Çözüm metnini tek mesaj olarak yapıştırın.\n"
                f"Soru: {session.question.public_id}\n"
                "İptal: /iptal",
                delete_photo_message_id=session.source_message_id,
            )
        if normalized in _NO:
            clear_session(telegram_user_id, question=session.question)
            remaining = TelegramBotSession.objects.filter(
                telegram_user_id=telegram_user_id
            ).count()
            extra = (
                f"\nBekleyen onay: {remaining} soru daha."
                if remaining
                else ""
            )
            return ConversationReply(
                "Tamam — soru panele gönderildi (onay bekliyor).\n"
                "Çözümü panelden istediğiniz zaman ekleyebilirsiniz."
                + extra
            )
        return ConversationReply(
            "Lütfen ilgili mesajdaki Evet veya Hayır düğmesine basın "
            "(iptal: /iptal)."
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
