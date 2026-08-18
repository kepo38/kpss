"""Gemini Vision — matematik / kesir / üs içeren soru görselleri için OCR."""

from __future__ import annotations

import base64
import json
import re
import urllib.error
import urllib.request
from typing import Any

from django.conf import settings

from .ocr import (
    OPTION_KEYS,
    OcrQuestionResult,
    _likely_geometry_question,
    _peel_embedded_options,
    _strip_watermarks,
    normalize_turkish_text,
    parse_question_text,
    strip_option_emphasis,
)
from .svg_sanitize import extract_svg, is_safe_svg

_GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)

# Kota / 503 / 404 durumunda sırayla dene (ücretsiz katman)
_GEMINI_MODEL_FALLBACKS = (
    "gemini-2.0-flash",
    "gemini-1.5-flash-latest",
    "gemini-1.5-flash-8b",
    "gemini-flash-latest",
    "gemini-3.1-flash-lite",
    "gemini-3-flash-preview",
)

_PROMPT = """Bu görselde bir KPSS çoktan seçmeli soru var.
Görev: aşağıdaki JSON şablonunun tüm alanlarını doldur.
Şekil çizme. SVG / TikZ / HTML üretme. Yalnızca metin JSON yaz.

Kurallar:
- Türkçe karakterleri doğru yaz (ğüşıöç).
- Matematik ifadeleri LaTeX ile $...$ içinde yaz.
  Örnek üs: $\\frac{4^x-2^x}{2^x-2^{-x}} = 2^x - \\frac{1}{5}$
  Örnek kök: $\\sqrt{x} - \\sqrt{y} = 2\\sqrt{2}$, $\\sqrt{4xy}$
  Örnek oran: $\\frac{x}{y}$
- Üslü / kök / kesirleri LaTeX ile yaz; düz metinde Vx, 2V2 gibi OCR hatası üretme.
- Basit denklemleri ayrı satırda tek $...$ içine yaz. Eşitlik yerine uzun çizgi (—) yazma.
  Örnek bileşim: $g(x) = 2x + a$
  $(f \\circ g)(x) = 3x - a$
  $f(1) = 9$ olduğuna göre $f(9)$ değeri kaçtır?
- Dikey / sütun işlemi (alt alta toplama, çıkarma, çarpma):
  İşlem işaretini görselden birebir oku. Solda veya sayının önünde eksi varsa ASLA artıya çevirme.
  Düz satıra yığma (`AB8 + 16C = CA3` YANLIŞ). LaTeX array kullan:
  $$\\begin{array}{r} AB8 \\\\ -16C \\\\ \\hline CA3 \\end{array}$$
  Soru cümlesi array'in altında kalsın:
  "A, B ve C rakamları için
  $$\\begin{array}{r} AB8 \\\\ -16C \\\\ \\hline CA3 \\end{array}$$
  olduğuna göre $A + B + C$ toplamı kaçtır?"
  Çözümü de aynı işleme göre yaz (çıkarma ise çıkarma; 738 − 165 = 573 gibi).
- Şıklarda kalın/italik/altı çizili yok. Beş şık da dolu olsun. Sayı ve formül düz metin veya $...$ olsun.
  Örnek: {"A": "1", "B": "8", "C": "15", "D": "18", "E": "21"}
- Romen rakamlı şıklar (I ve II, III ve V vb.) olduğu gibi ayrı ayrı yazılsın; şık harfi (A–E) ile Romen rakamı karıştırılmasın.
  Örnek: {"A": "I ve II", "B": "I ve IV", "C": "II ve III", "D": "III ve V", "E": "IV ve V"}
- Watermark (ÖSYM vb.) metne dahil etme.

dogru_cevap:
- Yalnızca A, B, C, D veya E yaz.
- Görselde işaretli/daireli şık varsa onu kullan.
- İşaret yoksa soruyu çözüp doğru şıkkı yaz.

detayli_cozum:
- Görselde çözüm metni varsa onu aktar.
- Yoksa Türkçe, adım adım, öğretici bir çözüm yaz.
- Matematikte LaTeX ($...$) kullan.

Geometri sorusu ise:
- soru_metni: Şeklin yanındaki/altındaki verilen bilgiler + en sondaki soru cümlesi.
  Köşe harflerini (A, B, C…) soru_metnine serpiştirme; verilenler düzgün satırlar olsun.
  Örnek soru_metni:
  "ABCD eşkenar dörtgen
  D, C, E doğrusal
  |DC| = |CE|
  |AB| = 10 birim
  |BF| = 4 birim
  |BE| = x
  Yukarıdaki verilere göre x kaç birimdir?"
- siklar: Yalnızca cevap seçenekleri (tek sayı veya kısa ifade).
  Soru cümlesini, verilenleri veya şekil etiketlerini şıklara koyma.
  Kesir/üs varsa $...$ içinde LaTeX yaz: "$-\\frac{1}{2}$"
  Örnek: {"A": "$-1$", "B": "$-2$", "C": "$-\\frac{1}{2}$", "D": "$-\\frac{3}{2}$", "E": "$-\\frac{1}{4}$"}

Çıktı formatı kesinlikle şu JSON şablonunda olmalıdır (başka metin yok):
{
  "soru_metni": "...",
  "siklar": {"A": "...", "B": "...", "C": "...", "D": "...", "E": "..."},
  "dogru_cevap": "...",
  "detayli_cozum": "..."
}
"""

_SVG_PROMPT = """Bu görselde bir geometri sorusu var.
Görevin yalnızca şekli SVG olarak çizmek. Soru metni veya şık yazma.

Kurallar:
- Yalnızca geçerli <svg>...</svg> bloğu yaz (viewBox ve xmlns ekle).
- JSON, markdown, açıklama yok.
- Köşe harflerini (A, B, C, …) <text> ile doğru koordinatlara yerleştir.
- Diklik sembollerini (sağ açı işareti) ilgili köşeye çiz.
- Açı değerlerini (ör. 40°, 90°) ilgili yay/köşe üzerine yaz.
- Kenar uzunluklarını ilgili kenarın yanına yerleştir.
- Oranları ve ölçüleri görseldekiyle aynı tut.
- script, foreignObject, harici href kullanma.
"""

_PLACEHOLDER_OPTION = re.compile(r"(?i)^(?:şık\s*)?[a-e]\s*$")
_STEM_LEAK = re.compile(
    r"(?i)(yukarıdaki|buna göre|verilere|eşkenar|doğrusal|birim\b|\|[A-Z]{2}\|)"
)
_Q_SENTENCE = re.compile(
    r"(Yukarıdaki[^?\n]*\?|Buna göre[^?\n]*\?|Şekle göre[^?\n]*\?"
    r"|[^\n?]*kaç birimdir\?|[^\n?]*kaçtır\?)",
    re.IGNORECASE,
)
_OCR_LETTER_JUNK = re.compile(r"(?i)\b[cç]{2,}c\b|CcC")


def _option_looks_dirty(val: str) -> bool:
    s = (val or "").strip()
    if not s:
        return False
    if _PLACEHOLDER_OPTION.match(s):
        return True
    if len(s) > 48:
        return True
    if _STEM_LEAK.search(s):
        return True
    if _OCR_LETTER_JUNK.search(s):
        return True
    return False


def _options_need_repair(options: dict[str, str]) -> bool:
    for key in OPTION_KEYS:
        if _option_looks_dirty(options.get(key, "")):
            return True
    return False


def _combine_stem_options(stem: str, options: dict[str, str]) -> str:
    parts = [stem] if stem.strip() else []
    for key in OPTION_KEYS:
        val = (options.get(key) or "").strip()
        if val:
            parts.append(f"{key}) {val}")
    return "\n".join(parts)


def _absorb_question(stem: str, blob: str) -> str:
    match = _Q_SENTENCE.search(blob)
    if not match:
        return stem.strip()
    question = re.sub(r"\s+", " ", match.group(0)).strip()
    if question.lower() not in stem.lower():
        return "\n".join(p for p in (stem.strip(), question) if p).strip()
    return stem.strip()


def _labeled_numeric_options(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for letter, num in re.findall(
        r"(?i)(?:^|[\s>])([A-E])\s*[\)\.:]\s*(-?\d+(?:[.,]\d+)?)",
        text,
    ):
        found.setdefault(letter.upper(), num.replace(",", "."))
    for letter, num in re.findall(
        r"(?i)(?:^|[\s>])([A-E])\s+(\d{1,3})\b",
        text,
    ):
        found.setdefault(letter.upper(), num)
    return found


def _numbers_after_question(blob: str) -> list[str]:
    match = _Q_SENTENCE.search(blob)
    if not match:
        return []
    return re.findall(r"\b(\d{1,3})\b", blob[match.end() :])


def _assign_option_numbers(nums: list[str]) -> dict[str, str]:
    out = {k: "" for k in OPTION_KEYS}
    for i, key in enumerate(OPTION_KEYS):
        if i < len(nums):
            out[key] = nums[i]
    return out


def _repair_geometry_payload(
    stem: str,
    options: dict[str, str],
) -> tuple[str, dict[str, str]]:
    """Soru cümlesini A şıkkından ayır; şıkları kısa sayılara indir."""
    blob = _combine_stem_options(stem, options)
    stem = _absorb_question(stem, blob)

    if not _options_need_repair(options):
        return stem, options

    after = _numbers_after_question(blob)
    if len(after) >= 5:
        return stem, _assign_option_numbers(after[:5])

    labeled = _labeled_numeric_options(blob)
    if sum(1 for v in labeled.values() if v) >= 3:
        repaired = {k: labeled.get(k, "") for k in OPTION_KEYS}
        unused = [n for n in after if n not in repaired.values()]
        for key in OPTION_KEYS:
            if repaired[key]:
                continue
            if unused:
                repaired[key] = unused.pop(0)
                continue
            cur = (options.get(key) or "").strip()
            if re.fullmatch(r"-?\d+(?:[.,]\d+)?", cur):
                repaired[key] = cur.replace(",", ".")
        if sum(1 for v in repaired.values() if v) >= 3:
            return stem, repaired

    stem2, opts2 = parse_question_text(blob)
    clean = {
        k: v
        for k, v in opts2.items()
        if (v or "").strip() and not _option_looks_dirty(v)
    }
    if len(clean) >= 3:
        merged = {k: "" for k in OPTION_KEYS}
        merged.update(opts2)
        return (stem2 or stem).strip(), merged

    repaired = {k: (options.get(k) or "").strip() for k in OPTION_KEYS}
    for key in OPTION_KEYS:
        val = repaired[key]
        if re.fullmatch(r"-?\d+(?:[.,]\d+)?", val):
            repaired[key] = val.replace(",", ".")
        elif _option_looks_dirty(val):
            repaired[key] = ""
    unused = list(after)
    for key in OPTION_KEYS:
        if not repaired[key] and unused:
            repaired[key] = unused.pop(0)
    return stem, repaired


def _post_process_gemini_payload(
    stem: str,
    options: dict[str, str],
    figure_svg: str,
) -> tuple[str, dict[str, str]]:
    stem = _strip_watermarks(stem)
    if figure_svg or _likely_geometry_question(stem, options, stem):
        return _repair_geometry_payload(stem, options)
    return stem, options


def gemini_configured() -> bool:
    return bool(getattr(settings, "GEMINI_API_KEY", ""))


def _payload_stem(data: dict[str, Any]) -> str:
    for key in ("soru_metni", "soruMetni", "stem"):
        val = data.get(key)
        if val:
            return str(val)
    return ""


def _payload_figure(data: dict[str, Any]) -> str:
    for key in ("sekil_kodu", "sekilKodu", "figure_svg", "figure_tikz", "svg"):
        val = data.get(key)
        if val:
            code = extract_svg(str(val))
            if is_safe_svg(code):
                return code
    return ""


def _payload_options(data: dict[str, Any]) -> dict[str, str]:
    raw = data.get("siklar") or data.get("options") or {}
    options: dict[str, str] = {k: "" for k in OPTION_KEYS}

    def _clean_opt(val: Any) -> str:
        return strip_option_emphasis(normalize_turkish_text(str(val).strip()))

    if isinstance(raw, list):
        for i, key in enumerate(OPTION_KEYS):
            if i < len(raw) and raw[i] is not None:
                options[key] = _clean_opt(raw[i])
        return options
    if not isinstance(raw, dict):
        return options
    for key in OPTION_KEYS:
        val = raw.get(key) or raw.get(key.lower()) or ""
        options[key] = _clean_opt(val)
    return options


def _payload_answer(data: dict[str, Any]) -> str:
    for key in ("dogru_cevap", "dogruCevap", "correct_option", "cevap"):
        val = data.get(key)
        if val is None or val == "":
            continue
        text = str(val).strip().upper()
        for ch in text:
            if ch in OPTION_KEYS:
                return ch
    return ""


def _payload_solution(data: dict[str, Any]) -> str:
    for key in ("detayli_cozum", "detayliCozum", "solution", "cozum"):
        val = data.get(key)
        if val:
            return normalize_turkish_text(str(val).strip())
    return ""


# JSON \f \b \t \n \r kaçışları LaTeX komutlarından ters eğik çizgiyi yer.
_LATEX_JSON_CMDS = (
    "frac",
    "dfrac",
    "tfrac",
    "sqrt",
    "cdot",
    "times",
    "circ",
    "left",
    "right",
    "text",
    "beta",
    "alpha",
    "gamma",
    "theta",
    "leq",
    "geq",
    "neq",
    "begin",
    "end",
    "array",
    "hline",
    "rho",
    "nu",
    "nabla",
    "tau",
    "tan",
    "tilde",
    "pm",
    "mp",
    "infty",
    "sum",
    "int",
    "log",
    "sin",
    "cos",
    "overline",
    "underline",
)
_LATEX_JSON_CMD_PATTERN = "|".join(_LATEX_JSON_CMDS)
_LATEX_JSON_CONTROL_REPAIRS: tuple[tuple[str, str], ...] = (
    ("\x0crac", "\\frac"),
    ("\x08eta", "\\beta"),
    ("\x08egin", "\\begin"),
    ("\x09ext{", "\\text{"),
    ("\x09ext ", "\\text "),
    ("\x09imes", "\\times"),
    ("\x09heta", "\\theta"),
    ("\x09au", "\\tau"),
    ("\x09an", "\\tan"),
    ("\x09ilde", "\\tilde"),
    ("\x0dight", "\\right"),
    ("\x0dho", "\\rho"),
    ("\x0aeq", "\\neq"),
    ("\x0anu", "\\nu"),
    ("\x0aabla", "\\nabla"),
)


def repair_json_latex_escapes(text: str) -> str:
    """Gemini JSON'unda \\frac → form-feed+rac gibi bozulmaları düzelt."""
    if not text:
        return text
    for bad, good in _LATEX_JSON_CONTROL_REPAIRS:
        text = text.replace(bad, good)
    text = re.sub(r"\$rac\{", r"$\\frac{", text)
    text = re.sub(r"\$sqrt\{", r"$\\sqrt{", text)
    return text


def _double_latex_escapes_before_json(raw: str) -> str:
    """json.loads öncesi tek \\ ile yazılmış LaTeX komutlarını çiftle."""
    if not raw:
        return raw
    pat = re.compile(rf"(?<!\\)\\({_LATEX_JSON_CMD_PATTERN})\b")
    return pat.sub(lambda m: "\\\\" + m.group(1), raw)


def _repair_payload_strings(value: Any) -> Any:
    if isinstance(value, str):
        return repair_json_latex_escapes(value)
    if isinstance(value, dict):
        return {k: _repair_payload_strings(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_repair_payload_strings(v) for v in value]
    return value


def _extract_json(text: str) -> dict[str, Any]:
    text = (text or "").strip()
    if not text:
        return {}
    # ```json ... ``` sarmalayıcı
    fence = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if fence:
        text = fence.group(1)
    else:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            text = text[start : end + 1]
    text = _double_latex_escapes_before_json(text)
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return _repair_payload_strings(data)
        return {}
    except json.JSONDecodeError:
        return {}


def _model_candidates() -> list[str]:
    configured = (
        getattr(settings, "GEMINI_OCR_MODEL", "") or "gemini-flash-latest"
    ).strip()
    out: list[str] = []
    for model in (configured, *_GEMINI_MODEL_FALLBACKS):
        if model and model not in out:
            out.append(model)
    return out


def _post_gemini_model(
    image_bytes: bytes,
    mime: str,
    model: str,
    prompt: str = _PROMPT,
    *,
    timeout: int = 45,
    json_mode: bool = True,
) -> str:
    api_key = settings.GEMINI_API_KEY
    url = f"{_GEMINI_URL.format(model=model)}?key={api_key}"
    b64 = base64.b64encode(image_bytes).decode("ascii")
    generation: dict[str, Any] = {"temperature": 0.1}
    if json_mode:
        generation["responseMimeType"] = "application/json"
    body = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {
                        "inline_data": {
                            "mime_type": mime or "image/png",
                            "data": b64,
                        }
                    },
                ]
            }
        ],
        "generationConfig": generation,
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Gemini HTTP {exc.code}: {detail[:400]}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Gemini bağlantı hatası: {exc.reason}") from exc

    candidates = payload.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini yanıt vermedi.")
    parts = (candidates[0].get("content") or {}).get("parts") or []
    texts = [p.get("text", "") for p in parts if p.get("text")]
    merged = "\n".join(texts).strip()
    if not merged:
        raise RuntimeError("Gemini boş yanıt döndü.")
    return merged


def _retryable(exc: RuntimeError) -> bool:
    msg = str(exc)
    return any(
        token in msg
        for token in ("429", "404", "403", "503", "UNAVAILABLE", "JSON ayrıştırılamadı", "boş yanıt")
    )


def _post_gemini(image_bytes: bytes, mime: str) -> tuple[dict[str, Any], str]:
    last_err: Exception | None = None
    for model in _model_candidates():
        try:
            raw = _post_gemini_model(
                image_bytes, mime, model, _PROMPT, timeout=45, json_mode=True
            )
            data = _extract_json(raw)
            if not data:
                raise RuntimeError("Gemini JSON ayrıştırılamadı.")
            return data, model
        except RuntimeError as exc:
            last_err = exc
            if _retryable(exc):
                continue
            raise
    if last_err:
        raise last_err
    raise RuntimeError("Gemini modelleri kullanılamıyor.")


def _svg_from_raw(raw: str) -> str:
    code = extract_svg(raw)
    if is_safe_svg(code):
        return code
    return _payload_figure(_extract_json(raw))


def _fetch_geometry_svg(image_bytes: bytes, mime: str) -> str:
    """İkinci çağrı: yalnızca SVG. Kırılırsa boş dön — metin OCR bozulmasın."""
    last_err: Exception | None = None
    for model in _model_candidates():
        try:
            raw = _post_gemini_model(
                image_bytes,
                mime,
                model,
                _SVG_PROMPT,
                timeout=60,
                json_mode=False,
            )
            fig = _svg_from_raw(raw)
            if fig:
                return fig
        except RuntimeError as exc:
            last_err = exc
            if _retryable(exc):
                continue
            return ""
        except Exception:  # noqa: BLE001
            return ""
    if last_err:
        return ""
    return ""


def ocr_question_image_gemini(
    image_bytes: bytes,
    mime: str = "image/png",
) -> OcrQuestionResult:
    """Görsel → Gemini Vision → stem + A–E."""
    if not gemini_configured():
        return OcrQuestionResult(
            stem="",
            options={k: "" for k in OPTION_KEYS},
            raw_text="",
            ok=False,
            error="GEMINI_API_KEY tanımlı değil.",
        )
    try:
        data, model_used = _post_gemini(image_bytes, mime)
    except Exception as exc:  # noqa: BLE001
        return OcrQuestionResult(
            stem="",
            options={k: "" for k in OPTION_KEYS},
            raw_text="",
            ok=False,
            error=str(exc),
            engine="gemini",
        )

    stem = normalize_turkish_text(_payload_stem(data))
    options = _peel_embedded_options(_payload_options(data))
    figure_svg = _payload_figure(data)
    correct_option = _payload_answer(data)
    solution = _payload_solution(data)
    stem, options = _post_process_gemini_payload(stem, options, figure_svg)

    # JSON şıkları eksikse ham metinden ayrıştır
    if sum(1 for v in options.values() if v) < 3:
        raw_join = stem + "\n" + "\n".join(
            f"{k}) {options[k]}" for k in OPTION_KEYS if options[k]
        )
        stem2, opts2 = parse_question_text(raw_join)
        if stem2:
            stem = stem2
        for k in OPTION_KEYS:
            if not options[k] and opts2.get(k):
                options[k] = opts2[k]
        stem, options = _post_process_gemini_payload(stem, options, figure_svg)

    if not figure_svg and _likely_geometry_question(stem, options, stem):
        figure_svg = _fetch_geometry_svg(image_bytes, mime)

    filled = sum(1 for v in options.values() if v)
    ok = bool(stem and filled >= 2)
    raw_text = json.dumps(
        {
            "soru_metni": stem,
            "siklar": options,
            "dogru_cevap": correct_option,
            "detayli_cozum": solution,
            "sekil_kodu": figure_svg,
        },
        ensure_ascii=False,
    )
    return OcrQuestionResult(
        stem=stem,
        options=options,
        raw_text=raw_text,
        ok=ok,
        error="" if ok else "Gemini soruyu okuyamadı.",
        engine=f"gemini:{model_used}",
        figure_svg=figure_svg,
        correct_option=correct_option,
        solution=solution,
    )
