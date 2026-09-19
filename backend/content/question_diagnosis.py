"""Bozuk soru teşhisi — public_id ile C1/C2/C3/H1 ve kalıcı PNG envanteri."""

from __future__ import annotations

from dataclasses import dataclass, field

from django.core.files.storage import default_storage

from content.models import OcrIngestLog, Question
from content.option_image_crop import VISUAL_OPTION_PLACEHOLDER
from content.telegram_panel import TelegramOcrFlags, telegram_question_ocr_flags

_PLACEHOLDER_STEM = "Aşağıdaki görsele göre cevaplayınız."


@dataclass(frozen=True)
class PermanentPngInfo:
    stem_or_scan: str | None = None
    option_images: dict[str, str] = field(default_factory=dict)
    solution_image: str | None = None
    map_image: str | None = None

    @property
    def has_option_pngs(self) -> bool:
        return bool(self.option_images)

    @property
    def has_stem_png(self) -> bool:
        return bool(self.stem_or_scan)


@dataclass(frozen=True)
class QuestionDiagnosis:
    found: bool
    public_id: str
    question_id: int | None = None
    flags: TelegramOcrFlags | None = None
    h1_stem_image: bool = False
    c1_text_ocr: bool = False
    c2_crop_geometry: bool = False
    c3_transparent_png: bool = False
    permanent_png: PermanentPngInfo | None = None
    priority_codes: tuple[str, ...] = ()
    summary_lines: tuple[str, ...] = ()
    panel_edit_path: str | None = None

    @property
    def likely_primary(self) -> str | None:
        return self.priority_codes[0] if self.priority_codes else None


def _storage_path(file_field) -> str | None:
    if not file_field:
        return None
    name = getattr(file_field, "name", "") or ""
    return name.strip() or None


def _classify_png_storage(path: str | None) -> str | None:
    if not path:
        return None
    base = path.rsplit("/", 1)[-1]
    if base.startswith("map_"):
        return "map"
    if base.startswith("stem_"):
        return "stem"
    if base.startswith("opt_"):
        return "option"
    if base.startswith("solution_"):
        return "solution"
    return "other"


def permanent_png_info(question: Question) -> PermanentPngInfo:
    stem_path = _storage_path(question.image)
    stem_kind = _classify_png_storage(stem_path)
    option_images: dict[str, str] = {}
    for letter in "ABCDE":
        path = _storage_path(getattr(question, f"option_{letter.lower()}_image"))
        if path:
            option_images[letter] = path
    return PermanentPngInfo(
        stem_or_scan=stem_path if stem_kind in (None, "stem", "other") else stem_path,
        option_images=option_images,
        solution_image=_storage_path(question.solution_image),
        map_image=stem_path if stem_kind == "map" else None,
    )


def _missing_option_images(question: Question) -> list[str]:
    if not question.options_are_images:
        return []
    missing: list[str] = []
    for letter in "ABCDE":
        opts = (getattr(question, f"option_{letter.lower()}") or "").strip()
        if opts in ("", "—", "-", VISUAL_OPTION_PLACEHOLDER):
            continue
        path = _storage_path(getattr(question, f"option_{letter.lower()}_image"))
        if not path:
            missing.append(letter)
            continue
        if not default_storage.exists(path):
            missing.append(letter)
    return missing


def _option_png_on_disk_but_not_visual(question: Question) -> bool:
    if question.options_are_images:
        return False
    for letter in "ABCDE":
        path = _storage_path(getattr(question, f"option_{letter.lower()}_image"))
        if path and default_storage.exists(path):
            return True
    return False


def diagnose_question_public_id(public_id: str) -> QuestionDiagnosis:
    pid = (public_id or "").strip()
    if not pid:
        return QuestionDiagnosis(
            found=False,
            public_id="",
            summary_lines=("public_id bos.",),
        )

    try:
        question = Question.objects.select_related("topic", "topic__subject").get(
            public_id=pid
        )
    except Question.DoesNotExist:
        return QuestionDiagnosis(
            found=False,
            public_id=pid,
            summary_lines=(
                f"Kayit yok: {pid}",
                "Once risk skoru icin panel/onay-bekleyen-sorular veya OcrIngestLog kontrol edilir.",
                "C2 (kırpma/okuma sirasi) ve C3 (seffaf PNG) oncelikli siniflandirma.",
            ),
        )

    flags = telegram_question_ocr_flags(question)
    png = permanent_png_info(question)
    missing_opts = _missing_option_images(question)
    stem = (question.stem or "").strip()

    h1 = bool(
        png.stem_or_scan
        or png.map_image
        or stem == _PLACEHOLDER_STEM
        or (question.figure_svg or "").strip()
        or (question.map_template or "").strip()
    )
    c1 = bool(flags.formula_missing or flags.char_drift or flags.partial)
    c2 = bool(
        question.options_are_images and (missing_opts or flags.partial)
    ) or _option_png_on_disk_but_not_visual(question)
    c3 = bool(
        question.options_are_images
        and (missing_opts or not png.has_option_pngs or len(png.option_images) < 3)
    )

    priority: list[str] = []
    if c2:
        priority.append("C2")
    if c3:
        priority.append("C3")
    if c1:
        priority.append("C1")
    if h1:
        priority.append("H1")
    if not priority:
        priority.append("OK")

    lines: list[str] = [
        f"public_id={question.public_id} pk={question.pk}",
        f"risk_score={flags.risk_score} "
        f"(partial={flags.partial} formula={flags.formula_missing} "
        f"char={flags.char_drift} dup={flags.duplicate_hint})",
        f"options_are_images={question.options_are_images} published={question.is_published}",
    ]
    if missing_opts:
        lines.append(f"C2: eksik/kayip sik PNG: {', '.join(missing_opts)}")
    if png.stem_or_scan:
        lines.append(f"Kalici ust goruntu: {png.stem_or_scan}")
    elif question.options_are_images:
        lines.append("Kalici ust goruntu yok (gorsel sik — tarama PNG beklenen)")
    else:
        lines.append("Kalici ust goruntu yok")
    if png.option_images:
        lines.append(
            "Kalici sik PNG: "
            + ", ".join(f"{k}={v}" for k, v in sorted(png.option_images.items()))
        )
    if png.solution_image:
        lines.append(f"Cozum PNG: {png.solution_image}")

    img_hash = (question.source_image_hash or "").strip()
    if img_hash:
        log = (
            OcrIngestLog.objects.filter(source_image_hash=img_hash)
            .order_by("-created_at")
            .first()
        )
        if log is not None:
            lines.append(
                f"OcrIngestLog id={log.pk} ok={log.ok} "
                f"formula_missing={log.issue_formula_missing} "
                f"char_drift={log.issue_char_drift} "
                f"dup={bool(log.duplicate_question_id)}"
            )

    primary = priority[0]
    if primary in ("C2", "C3"):
        lines.append(f"Oncelik: {primary} (kırpma/seffaf PNG) — H1/kalici PNG ayir")
    elif primary == "H1":
        lines.append("Oncelik: H1 (ust goruntu/kok metin) — kalici PNG envanterine bak")
    elif primary == "C1":
        lines.append("Oncelik: C1 (metin OCR)")

    panel_path = None
    if question.topic_id:
        panel_path = f"/panel/konu/{question.topic_id}/soru/{question.pk}/"

    return QuestionDiagnosis(
        found=True,
        public_id=question.public_id,
        question_id=question.pk,
        flags=flags,
        h1_stem_image=h1,
        c1_text_ocr=c1,
        c2_crop_geometry=c2,
        c3_transparent_png=c3,
        permanent_png=png,
        priority_codes=tuple(priority),
        summary_lines=tuple(lines),
        panel_edit_path=panel_path,
    )
