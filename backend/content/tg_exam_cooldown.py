"""Geriye dönük import — yeni kod: content.tg_exam.cooldown"""

from .tg_exam.cooldown import (  # noqa: F401
    COOLDOWN_DIFFICULTIES,
    TG_EXAM_COOLDOWN_DAYS,
    TG_EXAM_COOLDOWN_EXAM_COUNT,
    cooldown_excluded_public_ids,
    is_question_on_cooldown,
    recent_tg_exam_question_ids,
    record_tg_exam_question_usage,
)
