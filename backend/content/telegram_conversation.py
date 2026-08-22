"""Telegram bot çok adımlı konuşma — çözüm yapıştırma akışı."""

from __future__ import annotations

from dataclasses import dataclass

from .embeddings import refresh_question_embedding
from .models import Question, TelegramBotSession
from .rich_text import normalize_pasted_solution

_YES = frozenset({"evet", "e", "yes", "y"})
_NO = frozenset({"hayır", "hayir", "h", "no", "n"})


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
    TelegramBotSession.objects.update_or_create(
        telegram_user_id=telegram_user_id,
        defaults={
            "chat_id": chat_id,
            "step": TelegramBotSession.STEP_SOLUTION_YES_NO,
            "question": question,
            "source_message_id": source_message_id,
        },
    )


def clear_session(telegram_user_id: int) -> None:
    TelegramBotSession.objects.filter(telegram_user_id=telegram_user_id).delete()


def get_session(telegram_user_id: int) -> TelegramBotSession | None:
    return (
        TelegramBotSession.objects.filter(telegram_user_id=telegram_user_id)
        .select_related("question")
        .first()
    )


def solution_prompt_message() -> str:
    return (
        "Çözüm eklemek ister misiniz?\n"
        "(Google'dan kopyalayıp yapıştırabilirsiniz — paneldeki çözüm "
        "alanına yazılır.)\n"
        "Aşağıdaki düğmelerden seçin."
    )


def solution_prompt_keyboard() -> dict[str, list[list[dict[str, str]]]]:
    return {
        "inline_keyboard": [
            [
                {"text": "Evet", "callback_data": "sol_yes"},
                {"text": "Hayır", "callback_data": "sol_no"},
            ]
        ]
    }


CALLBACK_SOLUTION_YES = "sol_yes"
CALLBACK_SOLUTION_NO = "sol_no"


def try_handle_conversation_callback(
    callback_data: str,
    telegram_user_id: int,
) -> ConversationReply | None:
    if callback_data == CALLBACK_SOLUTION_YES:
        return try_handle_conversation(telegram_user_id, "evet")
    if callback_data == CALLBACK_SOLUTION_NO:
        return try_handle_conversation(telegram_user_id, "hayır")
    return None


def try_handle_conversation(
    telegram_user_id: int,
    text: str,
    *,
    cancel: bool = False,
    entities: list[dict] | None = None,
) -> ConversationReply | None:
    session = get_session(telegram_user_id)
    if session is None:
        return None

    if cancel:
        clear_session(telegram_user_id)
        return ConversationReply("Çözüm adımı iptal edildi.")

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
            clear_session(telegram_user_id)
            return ConversationReply(
                "Tamam — soru fotoğrafı sohbette kaldı.\n"
                "Çözümü panelden istediğiniz zaman düzenleyebilirsiniz."
            )
        return ConversationReply("Lütfen Evet veya Hayır düğmesine basın (iptal: /iptal).")

    if session.step == TelegramBotSession.STEP_SOLUTION_TEXT:
        solution = normalize_pasted_solution(text, entities=entities)
        if not solution:
            return ConversationReply(
                "Boş metin — çözümü yapıştırın veya /iptal ile vazgeçin."
            )
        question = session.question
        question.solution = solution
        question.save(update_fields=["solution"])
        refresh_question_embedding(question)
        clear_session(telegram_user_id)
        return ConversationReply(
            "Çözüm kaydedildi.\n"
            f"Kimlik: {question.public_id}\n"
            "Panel → Onay bekleyen sorular → İncele → çözüm alanında görünür."
        )

    clear_session(telegram_user_id)
    return None
