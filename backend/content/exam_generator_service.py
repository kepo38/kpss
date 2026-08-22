"""Geriye dönük import — yeni kod: content.tg_exam paketi."""

from .tg_exam.distribution import DEFAULT_TG_EXAM_DISTRIBUTION  # noqa: F401
from .tg_exam.generator import (  # noqa: F401
    ExamGeneratorError,
    ExamGeneratorService,
    TgExamGeneratorError,
    TgExamGeneratorService,
    generate_tg_exam_questions,
)
