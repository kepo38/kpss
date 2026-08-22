"""Geriye dönük import — yeni kod: content.tg_exam.generator"""

from .tg_exam.generator import (  # noqa: F401
    DEFAULT_TG_EXAM_DISTRIBUTION,
    ExamGeneratorError,
    ExamGeneratorService,
    TgExamGeneratorError,
    TgExamGeneratorService,
    generate_tg_exam_questions,
)
