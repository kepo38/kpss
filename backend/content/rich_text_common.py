"""Panel ve Telegram çözüm metni normalizasyonu — ortak yardımcılar.

Panel (`rich_text_panel`) ve Telegram (`rich_text_telegram`) ayrı giriş
noktalarına sahiptir; bu modül paylaşılan LaTeX/markdown/HTML dönüşümlerini içerir.
"""

from __future__ import annotations

import re
import unicodedata

from .ocr import normalize_turkish_text

_ZWSP_RE = re.compile(r"[\u200B-\u200D\uFEFF]")
_HTML_TAG_RE = re.compile(r"</?[a-zA-Z][^>]*>")
_BULLET_PREFIX_RE = re.compile(r"^(?:\s*[-•*◦○–—]\s+){2,}", re.MULTILINE)
_BULLET_LINE_RE = re.compile(r"^\s*[-•*◦○–—]\s+", re.MULTILINE)
_EMPTY_BULLET_RE = re.compile(r"^\s*[-•*◦○–—]\s*$", re.MULTILINE)
_MULTI_NL_RE = re.compile(r"\n{3,}")
_MATH_HOLDER_RE = re.compile(r"§§M(\d+)§§")
_MD_HOLDER_RE = re.compile(r"§§K(\d+)§§")

_ENTITY_DECODERS = (
    ("&nbsp;", " "),
    ("&amp;", "&"),
    ("&lt;", "<"),
    ("&gt;", ">"),
    ("&quot;", '"'),
    ("&#39;", "'"),
    ("&apos;", "'"),
    ("&rarr;", "→"),
)
_ENTITY_NUM_RE = re.compile(r"&#(\d+);")
_ENTITY_HEX_RE = re.compile(r"&#x([0-9a-fA-F]+);", re.IGNORECASE)

_BOLD_STYLE_RE = re.compile(
    r"font-weight\s*:\s*(bold|bolder|[6-9]00)|"
    r"mso-(?:bidi|ansi)-font-weight\s*:\s*bold",
    re.IGNORECASE,
)
_ITALIC_STYLE_RE = re.compile(r"font-style\s*:\s*italic", re.IGNORECASE)
_UNDERLINE_STYLE_RE = re.compile(
    r"text-decoration(?:-line)?\s*:[^;]*underline|"
    r"text-underline\s*:\s*single|"
    r"mso-text-underline",
    re.IGNORECASE,
)

_NESTED_MARK_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"^\*{3,}(?=[^*])"), "**"),
    (re.compile(r"\*\*__\*\*([^*]+)\*\*__\*\*"), r"**__\1__**"),
    (re.compile(r"__\*\*__([^_]+)__\*\*__"), r"__**\1**__"),
    (re.compile(r"\*\*\s*\*\*([^*]+)\*\*\s*\*\*"), r"**\1**"),
    (re.compile(r"__\s*__([^_]+)__\s*__"), r"__\1__"),
    (re.compile(r"\*{4,}([^*\n]+)\*{4,}"), r"**\1**"),
    (re.compile(r"_{4,}([^_\n]+)_{4,}"), r"__\1__"),
)

_TIGHTEN_PATTERNS: tuple[tuple[re.Pattern[str], str, str], ...] = (
    (
        re.compile(
            r"\*\*\s+([^*\n]+?\([A-E]\s+seçeneği\)\s*:)\*\*",
            re.IGNORECASE,
        ),
        "**",
        "**",
    ),
    (re.compile(r"(?<!\S)\*\*\s+([^*\n]+?:)\*\*"), "**", "**"),
    (re.compile(r"(?<!\S)\*\*[ \t]+([^*\n]+?)[ \t]+\*\*"), "**", "**"),
    (re.compile(r"__[ \t]+([^_\n]+?)[ \t]+__"), "__", "__"),
    (re.compile(r"(?<!\*)\*[ \t]+([^*\n]+?)[ \t]+\*(?!\*)"), "*", "*"),
    (re.compile(r"(?<!\S)\*\*([^*\n]+?)[ \t]+\*\*"), "**", "**"),
    (re.compile(r"__([^_\n]+?)[ \t]+__"), "__", "__"),
)

_EXTERIOR_BOLD_OPEN = re.compile(
    r"([0-9A-Za-zĞğİıÖöŞşÜüÇç'’])(\*\*)(?!\*)(?=[0-9A-Za-zĞğİıÖöŞşÜüÇç'’])"
)
_EXTERIOR_BOLD_CLOSE = re.compile(
    r"(?<=[^\s*])(\*\*)(?!\*)([0-9A-Za-zĞğİıÖöŞşÜüÇç'’])"
)
_EXTERIOR_UNDER_OPEN = re.compile(
    r"([0-9A-Za-zĞğİıÖöŞşÜüÇç'’])(__)(?!_)(?=[0-9A-Za-zĞğİıÖöŞşÜüÇç'’])"
)
_EXTERIOR_UNDER_CLOSE = re.compile(
    r"(?<=[^\s_])(__)(?!_)([0-9A-Za-zĞğİıÖöŞşÜüÇç'’])"
)

_SPLIT_BOLD_RE = re.compile(
    r"(?<!\S)\*\*([^\n*][^\n*]*?)\n\s+([^\n*][^\n*]*?)\*\*"
)

_COMBINED_BOLD_UNDER_RE = re.compile(
    r"<(?:strong|b)\b[^>]*>\s*<u\b[^>]*>([\s\S]*?)</u\s*>\s*</(?:strong|b)\s*>|"
    r"<u\b[^>]*>\s*<(?:strong|b)\b[^>]*>([\s\S]*?)</(?:strong|b)\s*>\s*</u\s*>",
    re.IGNORECASE,
)

_SIMPLE_TAG_RES: tuple[tuple[str, str], ...] = (
    ("strong", "**"),
    ("b", "**"),
    ("em", "*"),
    ("i", "*"),
    ("u", "__"),
)

_SPAN_STYLE_RE = re.compile(
    r"""<span\b([^>]*)>([\s\S]*?)</span\s*>""",
    re.IGNORECASE,
)

_HAS_LATEX_RE = re.compile(
    r"\$\$|\$[^$\n]+\$|\\\(|\\\[|\\frac|\\sqrt|\\circ|\\cdot|\\left|\\right|\\begin\{|\\hline"
)
_LATEX_SCORE_FRAC_RE = re.compile(
    r"\\(?:frac|sqrt|circ|cdot|left|right|text)"
)

_NAMED_SOLUTION_LABEL_RE = re.compile(
    r"(Mühimme\s+Defteri\s*:|Kimin\s+Sorumluluğundadır\s*\?|"
    r"(?:KPSS\s+)?Hap\s+Bilgi\s*:)",
    re.IGNORECASE,
)
_NAMED_SOLUTION_SPLIT_RE = re.compile(
    r"(?<!^)(?<!\n)\s*(?="
    r"Mühimme\s+Defteri\s*:|Kimin\s+Sorumluluğundadır\s*\?|"
    r"KPSS\s+Hap\s+Bilgi\s*:|(?<!KPSS\s)Hap\s+Bilgi\s*:)",
    re.IGNORECASE,
)


def _format_named_solution_sections(text: str) -> str:
    """Yapışık bilgi etiketlerini kalın, ayrı paragraflara dönüştür."""
    src = (text or "").strip()
    if not src:
        return src

    # Önceden eklenmiş dış markdown'ı kaldırıp tek, geçerli çift yıldız üret.
    src = re.sub(
        rf"\*\*\s*({_NAMED_SOLUTION_LABEL_RE.pattern})\s*\*\*",
        r"\1",
        src,
        flags=re.IGNORECASE,
    )
    src = _NAMED_SOLUTION_SPLIT_RE.sub("\n\n", src)
    src = re.sub(
        rf"(?m)^[ \t]*(?:[-•◦○–—]\s+)?({_NAMED_SOLUTION_LABEL_RE.pattern})[ \t]*",
        lambda match: f"**{match.group(1).strip()}** ",
        src,
        flags=re.IGNORECASE,
    )
    return re.sub(r"\n{3,}", "\n\n", src).strip()


def _decode_entities(text: str) -> str:
    out = text
    for src, dst in _ENTITY_DECODERS:
        out = out.replace(src, dst)
    out = _ENTITY_NUM_RE.sub(
        lambda m: chr(int(m.group(1))) if int(m.group(1)) < 0x110000 else m.group(0),
        out,
    )
    out = _ENTITY_HEX_RE.sub(
        lambda m: (
            chr(int(m.group(1), 16))
            if int(m.group(1), 16) < 0x110000
            else m.group(0)
        ),
        out,
    )
    return out


def _utf16_len(char: str) -> int:
    return 2 if ord(char) > 0xFFFF else 1


def _utf16_index_to_py(text: str, utf16_offset: int) -> int:
    units = 0
    for index, char in enumerate(text):
        if units >= utf16_offset:
            return index
        units += _utf16_len(char)
    return len(text)


def _fully_wrapped(text: str, mark: str) -> bool:
    n = len(mark)
    if len(text) < n * 2:
        return False
    if not text.startswith(mark) or not text.endswith(mark):
        return False
    return mark not in text[n:-n]


def _wrap_markdown_node(
    text: str,
    *,
    bold: bool,
    italic: bool,
    underline: bool,
) -> str:
    raw = text
    lead = re.match(r"^[ \t]+", raw)
    trail = re.search(r"[ \t]+$", raw)
    lead_s = lead.group(0) if lead else ""
    trail_s = trail.group(0) if trail else ""
    core = raw[len(lead_s) : len(raw) - len(trail_s)].strip()
    if not core:
        return raw
    if not italic and re.fullmatch(r"\*\*__.+__\*\*", core) and (bold or underline):
        return raw
    if bold and re.fullmatch(r"__\*\*.+\*\*__", core):
        return raw
    if underline and re.fullmatch(r"\*\*__.+__\*\*", core):
        return raw
    if bold and _fully_wrapped(core, "**"):
        core = core[2:-2].strip()
    if underline and _fully_wrapped(core, "__"):
        core = core[2:-2].strip()
    if italic and _fully_wrapped(core, "*") and not _fully_wrapped(core, "**"):
        core = core[1:-1].strip()
    if bold and underline and not italic:
        core = f"**__{core}__**"
    elif bold and italic:
        core = f"***{core}***"
    elif bold:
        core = f"**{core}**"
    elif italic:
        core = f"*{core}*"
    if underline and not (bold and underline and not italic):
        core = f"__{core}__"
    return f"{lead_s}{core}{trail_s}"


def _replace_simple_html_tags(text: str) -> str:
    text = _COMBINED_BOLD_UNDER_RE.sub(
        lambda m: f"__**{(m.group(1) or m.group(2) or '').strip()}**__",
        text,
    )
    for tag, marker in _SIMPLE_TAG_RES:
        pattern = re.compile(
            rf"<{tag}\b[^>]*>([\s\S]*?)</{tag}\s*>",
            re.IGNORECASE,
        )

        def _tag_repl(match: re.Match[str], mk: str = marker) -> str:
            return _wrap_markdown_node(
                match.group(1) or "",
                bold=mk == "**",
                italic=mk == "*",
                underline=mk == "__",
            )

        text = pattern.sub(_tag_repl, text)
    for _ in range(8):
        next_text = _SPAN_STYLE_RE.sub(_convert_span, text)
        if next_text == text:
            break
        text = next_text
    text = _HTML_TAG_RE.sub("", text)
    return text


def _convert_span(match: re.Match[str]) -> str:
    attrs = match.group(1) or ""
    inner = (match.group(2) or "").strip()
    if not inner:
        return ""
    style_m = re.search(r"""style\s*=\s*["']([^"']*)["']""", attrs, re.I)
    cls_m = re.search(r"""class\s*=\s*["']([^"']*)["']""", attrs, re.I)
    style = (style_m.group(1) if style_m else "").lower()
    cls = (cls_m.group(1) if cls_m else "").lower()
    bold = bool(_BOLD_STYLE_RE.search(style)) or any(
        token in cls for token in ("bold", "strong", "font-bold")
    )
    italic = bool(_ITALIC_STYLE_RE.search(style)) or "italic" in cls
    underline = bool(_UNDERLINE_STYLE_RE.search(style)) or "underline" in cls
    if not (bold or italic or underline):
        return inner
    return _wrap_markdown_node(inner, bold=bold, italic=italic, underline=underline)


def html_to_markdown(html: str) -> str:
    text = _decode_entities(html)
    # Google Docs XPM: data-xpm-latex → $…$ (SVG/MathML düşmeden önce)
    text = re.sub(
        r'<[^>]*\bdata-xpm-latex\s*=\s*"([^"]+)"[^>]*>',
        lambda m: (
            f"$${m.group(1).strip()}$$"
            if re.search(r'data-xpm-math-type\s*=\s*"block"', m.group(0), re.I)
            else f"${m.group(1).strip()}$"
        ),
        text,
        flags=re.I,
    )
    text = re.sub(r"<svg\b[^>]*>[\s\S]*?</svg\s*>", "", text, flags=re.I)
    text = re.sub(r"<math\b[^>]*>[\s\S]*?</math\s*>", "", text, flags=re.I)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"</p\s*>", "\n\n", text, flags=re.I)
    text = re.sub(r"<p\b[^>]*>", "", text, flags=re.I)
    text = re.sub(r"</li\s*>", "\n", text, flags=re.I)
    text = re.sub(r"<li\b[^>]*>", "\n- ", text, flags=re.I)
    text = re.sub(r"</?(?:ul|ol)\b[^>]*>", "\n", text, flags=re.I)
    text = re.sub(r"</div\s*>", "\n", text, flags=re.I)
    text = re.sub(r"<div\b[^>]*>", "", text, flags=re.I)
    text = re.sub(r"</h[1-4]\s*>", "\n\n", text, flags=re.I)
    text = re.sub(r"<h[1-4]\b[^>]*>", "## ", text, flags=re.I)
    text = _replace_simple_html_tags(text)
    text = _HTML_TAG_RE.sub("", text)
    text = text.replace("\u00a0", " ")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def html_clipboard_to_text(html: str) -> str:
    """rich-format.js htmlClipboardToText — HTML yapıştırma sonrası metin."""
    converted = html_to_markdown(html)
    converted = converted.replace("\u00a0", " ")
    converted = re.sub(r"[ \t]+\n", "\n", converted)
    converted = re.sub(r"\n{3,}", "\n\n", converted).strip()
    return collapse_bullet_prefixes(
        collapse_nested_marks(normalize_paste_text(converted))
    )


def repair_latex_escapes(text: str) -> str:
    """math-render.js repairLatexEscapes."""
    src = repair_google_docs_vert_bars(
        text.replace("\x0crac", r"\frac")
        .replace("\x08eta", r"\beta")
        .replace("\x08egin", r"\begin")
        .replace("\x08lacksquare", r"\blacksquare")
        .replace("\x09ext{", r"\text{")
        .replace("\x09imes", r"\times")
        .replace("\x09heta", r"\theta")
        .replace("\x09an", r"\tan")
        .replace("\x09riangle", r"\triangle")
        .replace("\x0dight", r"\right")
        .replace("\x0aeq", r"\neq")
        .replace("$rac{", r"$\frac{")
        .replace("$sqrt{", r"$\sqrt{")
    )
    if "frac" in src and r"\frac" not in src:
        src = re.sub(r"(^|[^\\A-Za-z])frac\{", r"\1\\frac{", src)
    return src


def repair_google_docs_vert_bars(text: str) -> str:
    r"""Google `\vert{}-3\vert{}` → `\lvert -3 \rvert`; `\(\vert{}\)` → `|`."""
    src = text or ""
    src = re.sub(r"\\\(\s*\\vert\{\}\s*\\\)", "|", src)
    src = src.replace("(\\vert{})", "|")
    src = re.sub(
        r"\\vert\{\}([^\\]*?)\\vert\{\}",
        lambda m: (
            r"\lvert " + m.group(1).strip() + r" \rvert"
            if m.group(1).strip()
            else r"\vert"
        ),
        src,
    )
    return src


def repair_vert_groups(text: str) -> str:
    r"""Geçersiz `\vert{…\vert}` → `\lvert … \rvert` (ortak; Telegram modülü de kullanır)."""
    src = repair_google_docs_vert_bars(text or "")
    src = re.sub(
        r"\\vert\s*\{([^{}]*?)\\vert(?:\{\})?\}",
        lambda m: r"\lvert " + m.group(1).strip() + r" \rvert",
        src,
    )
    return src


def _inline_latex_body_to_dollars(body: str) -> str:
    """\\(...\\) → $...$; tabular gövde $$...$$ (önizleme hizası)."""
    cleaned = (body or "").strip()
    if "\n" in cleaned:
        cleaned = re.sub(r"\s*\n\s*", " ", cleaned).strip()
    if re.search(r"\\begin\{(?:array|matrix|pmatrix|cases)\}", cleaned):
        return f"$${cleaned}$$"
    return f"${cleaned}$"


def _display_latex_body_to_dollars(body: str) -> str:
    return f"$${(body or '').strip()}$$"


# Google yapıştırma: GösterimKitabın / sayfaİlk — 5A, pH, iPhone bölünmez.
_COLLAPSED_WORD_BOUNDARY_RE = re.compile(
    r"(?<=[a-zçğıöşüâîû]{2})(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])"
)


# ÖSYM kutu/üçgen operatörü: □AB / $\square AB$ → içerik şeklin içinde.
# `\shapebox{square}{AB}` / `\shapebox{triangle}{AB}` — panel + Flutter ortak.
_SYMBOLIC_SHAPE_CMD_RE = re.compile(
    r"(?<![A-Za-z])\\(square|triangle)(?![A-Za-z])\s*([A-Za-z0-9]+)"
)
_UNICODE_SHAPE_PREFIX_RE = re.compile(r"([□△])\s*([A-Za-z0-9]+)")
_SHAPEBOX_KIND = {"square": "square", "triangle": "triangle", "□": "square", "△": "triangle"}


def rewrite_symbolic_shape_operators(text: str) -> str:
    """`$\\square AB$` / `□73` → `$\\shapebox{square}{AB}$` (içerik şeklin içinde).

    Yalnızca operatör+içerik örüntüsünü çevirir; çıplak `\\square` / `\\triangle`
    sembolleri ve `\\triangleq` / `\\triangledown` gibi komutlar dokunulmaz.
    """
    src = text or ""
    if not src:
        return src

    def _cmd(match: re.Match[str]) -> str:
        kind = _SHAPEBOX_KIND.get(match.group(1), match.group(1))
        return rf"\shapebox{{{kind}}}{{{match.group(2)}}}"

    def _uni(match: re.Match[str]) -> str:
        kind = _SHAPEBOX_KIND.get(match.group(1), "square")
        return rf"\shapebox{{{kind}}}{{{match.group(2)}}}"

    src = _SYMBOLIC_SHAPE_CMD_RE.sub(_cmd, src)
    src = _UNICODE_SHAPE_PREFIX_RE.sub(_uni, src)
    return src


def normalize_latex(text: str) -> str:
    src = merge_split_inline_dollar_math(repair_latex_escapes(text or ""))
    # Uygulama hizası için gereksiz; OCR/Gemini artığı → sil
    src = re.sub(r"\\hphantom\s*\{[^{}]*\}", "", src)
    src = re.sub(r"\\phantom\s*\{[^{}]*\}", "", src)
    src = re.sub(
        r"\\\[([\s\S]+?)\\\]",
        lambda m: _display_latex_body_to_dollars(m.group(1)),
        src,
    )
    src = re.sub(
        r"\\\(([\s\S]+?)\\\)",
        lambda m: _inline_latex_body_to_dollars(m.group(1)),
        src,
    )
    return rewrite_symbolic_shape_operators(src)


def normalize_exam_arrows(text: str) -> str:
    src = text or ""
    src = re.sub(r"\$\\(?:long)?rightarrow\$", "→", src)
    src = src.replace(r"$\to$", "→")
    src = re.sub(r"\\(?:long)?rightarrow\b", "→", src)
    src = re.sub(r"&#0*8594;|&rarr;", "→", src, flags=re.I)
    src = re.sub(r"[ \t]*->[ \t]*", " → ", src)
    return src


def collapse_nested_marks(text: str) -> str:
    src = text
    while True:
        prev = src
        for pattern, repl in _NESTED_MARK_PATTERNS:
            src = pattern.sub(repl, src)
        if src == prev:
            break
    return src


def _peel_markers(full: str, inner: str, open_m: str, close_m: str) -> str:
    if "\n" in inner:
        return full
    lead_m = re.match(rf"^{re.escape(open_m)}([ \t]+)", full)
    trail_m = re.search(rf"([ \t]+){re.escape(close_m)}$", full)
    lead = lead_m.group(1) if lead_m else ""
    trail = trail_m.group(1) if trail_m else ""
    return f"{lead}{open_m}{inner.strip()}{close_m}{trail}"

def tighten_markdown_markers(text: str) -> str:
    src = collapse_nested_marks(text)
    for pattern, open_m, close_m in _TIGHTEN_PATTERNS:
        src = pattern.sub(
            lambda m, o=open_m, c=close_m: _peel_markers(m.group(0), m.group(1), o, c),
            src,
        )
    return src


def _protect_markdown_spans(text: str, holders: list[str]) -> str:
    def repl(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"§§K{len(holders) - 1}§§"

    return re.sub(r"\*\*[\s\S]+?\*\*|__[\s\S]+?__", repl, text)


def _restore_markdown_spans(text: str, holders: list[str]) -> str:
    def repl(match: re.Match[str]) -> str:
        idx = int(match.group(1))
        return holders[idx] if 0 <= idx < len(holders) else match.group(0)

    return _MD_HOLDER_RE.sub(repl, text)


def _ensure_markdown_exterior_spaces(text: str) -> str:
    holders: list[str] = []

    def hold(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"§§M{len(holders) - 1}§§"

    src = re.sub(r"\$\$[\s\S]+?\$\$|\$[^$\n]+\$", hold, text)
    src = _EXTERIOR_BOLD_OPEN.sub(r"\1 \2", src)
    src = _EXTERIOR_UNDER_OPEN.sub(r"\1 \2", src)
    src = _EXTERIOR_BOLD_CLOSE.sub(r"\1 \2", src)
    src = _EXTERIOR_UNDER_CLOSE.sub(r"\1 \2", src)
    src = _MATH_HOLDER_RE.sub(
        lambda m: holders[int(m.group(1))] if int(m.group(1)) < len(holders) else m.group(0),
        src,
    )
    return src


_BLOCK_UNDERLINE_LINE_RE = re.compile(r"^[ \t]*__(.+?)__[ \t]*$")
_BLOCK_UNDERLINE_HEADER_INNER_RE = re.compile(
    r"^(?:#{1,3}\s+|\d+\.\s*(?:Aşama|Adım)\b|\*\*.+\*\*)",
    re.IGNORECASE,
)


def _strip_markdown_heading_marks(text: str) -> str:
    return re.sub(r"^#{1,3}\s+", "", text.strip())


_ATX_HEADING_LINE_RE = re.compile(r"^[ \t]*(#{1,3})[ \t]+(.+?)[ \t]*#*[ \t]*$")


def convert_atx_headings_to_bold(text: str) -> str:
    """Gemini/ATX ``## Başlık`` satırlarını panel kanonik ``**Başlık**`` yap.

    Panel paste / uygulama çözümü ``#`` başlık işaretini depolamaz; kalın satır
    başlığı kullanır. Idempotent: zaten ``**…**`` olan satırlara dokunmaz.
    """
    if not text or "#" not in text:
        return text
    out: list[str] = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        match = _ATX_HEADING_LINE_RE.match(line)
        if not match:
            out.append(line)
            continue
        body = match.group(2).strip()
        body = re.sub(r"\s+#+\s*$", "", body).strip()
        bold_wrapped = re.match(r"^\*\*(.+)\*\*$", body, re.DOTALL)
        if bold_wrapped:
            body = bold_wrapped.group(1).strip()
        if not body:
            out.append(line)
            continue
        out.append(f"**{body}**")
    return "\n".join(out)


def demote_block_underline_markup(text: str) -> str:
    """Tam satır ``__…__`` ile sarılmış başlıkları ``**…**`` yap.

    ``__## 1. Aşama: …__`` gibi blok altı çizgiler önizlemede bir sonraki satırla
    birleşip layout bozuyor; kalın başlığa indirgenir.
    """
    if not text or "__" not in text:
        return text
    out: list[str] = []
    for line in text.split("\n"):
        match = _BLOCK_UNDERLINE_LINE_RE.match(line)
        if not match:
            out.append(line)
            continue
        inner = match.group(1).strip()
        if not _BLOCK_UNDERLINE_HEADER_INNER_RE.match(inner):
            out.append(line)
            continue
        body = _strip_markdown_heading_marks(inner)
        bold_stripped = re.match(r"^\*\*(.+)\*\*$", body.strip(), re.DOTALL)
        if bold_stripped:
            body = bold_stripped.group(1).strip()
        out.append(f"**{body.strip()}**")
    return "\n".join(out)


_BLOCK_UNDERLINE_SCAN_RE = re.compile(
    r"(?m)^[ \t]*__(?:#{1,3}\s+|\d+\.\s*(?:Aşama|Adım)\b|\*\*.+\*\*).+__\s*$",
    re.IGNORECASE,
)


def needs_block_underline_repair(text: str) -> bool:
    """Çözüm metninde ``__## …__`` / ``__1. Aşama …__`` gibi onarım gerektirir mi?"""
    return bool(text and _BLOCK_UNDERLINE_SCAN_RE.search(text))


def repair_block_underline_solution(text: str) -> str:
    """Yalnızca blok altı çizgili başlıkları indirger — tam normalizasyon yapmaz."""
    return demote_block_underline_markup(text or "")


_PASTE_FRAGMENT_MARKER_RES: tuple[re.Pattern[str], ...] = (
    re.compile(r"<!--\s*(?:Start|End)\s*Fragment-\s*→\s*", re.IGNORECASE),
    re.compile(r"<!--TgQPHd\|\|\|\[\]-\s*→\s*", re.IGNORECASE),
    re.compile(r"<!--TgQPHd[^>]*?-->", re.IGNORECASE),
    re.compile(r"<!--\s*(?:Start|End)[^>]*?-->", re.IGNORECASE | re.DOTALL),
)

# Word/Outlook yapıştırması: MSO conditional comment + @font-face stil dökümü
_WORD_MSO_SIGNAL_RE = re.compile(
    r"(?ix)"
    r"<!--\s*\[if\s+(?:gte\s+)?mso"
    r"|/\s*\*\s*Font Definitions"
    r"|/\s*\*\s*Style Definitions"
    r"|@font-face\b"
    r"|\bWordSection\d+\b"
    r"|\bp\.MsoNormal\b"
    r"|\bmso-[a-z0-9-]+\s*:"
)
_MSO_IF_BLOCK_RE = re.compile(
    r"<!--\s*\[if[^\]]*\]\s*>.*?<!\s*\[endif\]\s*(?:-->|>)?",
    re.IGNORECASE | re.DOTALL,
)
_MSO_IF_OPEN_RE = re.compile(r"<!--\s*\[if[^\]]*\]\s*>", re.IGNORECASE)
_MSO_ENDIF_RE = re.compile(r"<!\[endif\]\s*(?:-->|>)?", re.IGNORECASE)
# Kapanmamış ``<!-- … Font/Style Definitions …`` CSS gövdesi
# Bitiş: ``-->`` veya boş satır + gövde (harf / markdown liste-başlık)
_WORD_CSS_DEBRIS_RE = re.compile(
    r"<!--(?!\s*\[if)"
    r"(?:(?!-->)[\s\S])*?"
    r"(?:Font Definitions|Style Definitions|@font-face|mso-|WordSection|MsoNormal)"
    r"(?:(?!-->)[\s\S])*?"
    r"(?:-->|(?=\n\s*\n(?=(?:[A-Za-zÇĞİÖŞÜçğıöşü]|[-*#]))))",
    re.IGNORECASE,
)

_GOOGLE_XPM_SIGNAL_RE = re.compile(
    r"TgQPHd|data-xpm-latex|<!--\s*qkimaf|<!--\s*cqw1tb",
    re.IGNORECASE,
)
# Yarım kalmış XPM HTML (TgQPHd yok ama draggable/role sızmış)
_XPM_HTML_ATTR_DEBRIS_RE = re.compile(
    r"""(?ix)
    \bdraggable\s*=|
    \brole\s*=\s*["']?presentation|
    \baria-hidden\s*=|
    \bdata-xpm-[a-z0-9-]+\s*=|
    \$\s*=\s*\\?"
    """,
)
# Google Docs öneri/annotation JSON artığı (TgQPHd yokken de sızabilir)
# örn. ,"66":0}],0,0,null,null,0,0,[],"",0,0],"Rle…qQ0_0"]
_DOCS_ANNOTATION_TOKEN_DEBRIS_RE = re.compile(
    # ,"66":0}],0,0,null,…,[],"",0,0],"Rle…qQ0_0"]
    r""",?"\d{1,4}":\d+\}]"""
    r"""(?:,(?:null|\d+|\[\]|""|"[^"]*"))*"""
    r"""(?:\](?:,?"[^"]*")?)?\]?"""
)
# TgQPHd sonrası yalnız kalan kimlik kuyruğu: ,"Rle…qQ0_0"]
_DOCS_ANNOTATION_ID_TAIL_RE = re.compile(
    r""","[A-Za-z0-9_-]{8,}(?:qQ\d+_\d+)?"\]"""
)
# Google Docs XPM: kapanmayan ``<!--TgQPHd|||[[[…]]`` (--> yok).
_TGQPHD_BLOB_RE = re.compile(
    r"<!--TgQPHd\|\|\|(?:\[\[.*?\]\]|\[\])-?\s*→?",
    re.IGNORECASE | re.DOTALL,
)
_XPM_SIDE_MARKER_RE = re.compile(
    r"<!--\s*(?:qkimaf|cqw1tb)\b[^<\n]*(?:\n[^\n<]*)?",
    re.IGNORECASE,
)
_XPM_LATEX_ATTR_RE = re.compile(
    r'data-xpm-latex\s*=\s*"((?:\\.|[^"\\])*)"',
    re.IGNORECASE,
)
_XPM_SPEECH_DUP_RE = re.compile(
    # Herhangi bir satırda Google MathML konuşma: equals / end-fraction / …
    r"^[ \t]*.*\bequals\b.*$|"
    r"^[ \t]*.*\b(?:end-fraction|four-thirds|open paren|close paren)\b.*$|"
    r"^[ \t]*.*\bimplies\b.*$|"
    r"^[ \t]*.*\bcap\s+[A-Za-z]\b.*$|"
    r"^[ \t]*.*\b(?:cross|space)\b.*\b(?:equals|implies|plus|minus|cap)\b.*$|"
    r"^[ \t]*.*\b(?:plus|minus|cross)\b.*\b(?:equals|implies|paren)\b.*$",
    re.IGNORECASE | re.MULTILINE,
)
_XPM_SPEECH_GLUE_RE = re.compile(
    r"(?:four-thirds|open paren|close paren|\bcross\b|\bend-fraction\b|"
    r"\bplus\b|\bminus\b|\bspace\b)",
    re.IGNORECASE,
)
_GOOGLE_SPEECH_SIGNAL_RE = re.compile(
    r"\bequals\b|\bfour-thirds\b|\bend-fraction\b|\bcap\s+[A-Za-z]\b|"
    # ``\implies`` LaTeX komutu konuşma sinyali değil
    r"(?<!\\)\bimplies\b|\bopen paren\b|\bclose paren\b|(?<![A-Za-z])cap\s*[A-Za-z]\b|"
    r"\bplus\b|\bminus\b|\bspace\b",
    re.IGNORECASE,
)
# MathML annotation artığı: kısa sembol satırları (``x`` / ``+5`` / ``)`` / ``=3x``).
_XPM_MATH_FRAG_LINE_RE = re.compile(
    r"^[ \t]*[A-Za-z0-9+\-×÷=⇒→().,]{1,16}\s*$"
)


def _unescape_google_paste_escapes(text: str) -> str:
    """``\\u003c`` / ``\\\"`` gibi yapıştırma kaçışlarını çöz."""
    src = text or ""
    src = re.sub(
        r"\\u([0-9a-fA-F]{4})",
        lambda m: chr(int(m.group(1), 16)),
        src,
    )
    return src.replace(r"\"", '"').replace(r"\'", "'")


def _latex_from_xpm_blob(blob: str) -> str:
    """Blob içindeki tüm ``data-xpm-latex`` değerlerini ``$…$`` yap (çoklu destek)."""
    decoded = _unescape_google_paste_escapes(blob)
    parts: list[str] = []
    for match in _XPM_LATEX_ATTR_RE.finditer(decoded):
        latex = match.group(1)
        latex = latex.replace(r"\\", "\\")
        latex = (
            latex.replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&amp;", "&")
            .replace("&quot;", '"')
        )
        latex = latex.strip()
        if not latex:
            continue
        if latex.startswith("$") and latex.endswith("$"):
            parts.append(latex)
        else:
            parts.append(f"${latex}$")
    if not parts:
        return ""
    # Aynı blob'ta tekrarlayan latex'i tekilleştir
    uniq: list[str] = []
    for p in parts:
        if p not in uniq:
            uniq.append(p)
    return " ".join(uniq) if len(uniq) > 1 else uniq[0]


def _plain_formula_lookalike(plain: str) -> bool:
    """Düz metin formül kopyası mı? (Unicode/ASCII matematik artığı)."""
    s = (plain or "").strip()
    if not s or s.startswith("$"):
        return False
    # Uzun düzyazı değil
    if len(s) > 90:
        return False
    if re.search(r"[⇒→×÷]", s) and re.search(r"\d|[A-Za-z]", s):
        return True
    if re.fullmatch(r"[A-Za-z0-9+\-×÷=⇒→().,\s\\]+", s) and re.search(
        r"[+\-×÷=⇒→]", s
    ):
        return True
    if len(s) <= 64 and re.search(r"\d\s*[=×÷]", s):
        return True
    return False


def _drop_plain_prefix_before_inline_math(line: str) -> str:
    """``𝑀+3x=50(1)$M+3x=50$`` → ``$M+3x=50$`` (ardından metin kalsa da)."""
    match = re.search(r"(\$[^$\n]+\$)", line)
    if not match:
        return line
    prefix = line[: match.start()]
    suffix = line[match.end() :]
    if not prefix.strip():
        return line
    if _plain_formula_lookalike(prefix) or re.search(
        r"(?i)\b(?:cap|equals|implies|plus|minus)\b", prefix
    ) or (
        len(prefix.strip()) <= 80
        and "=" in prefix
        and re.search(r"\d", prefix)
        and not prefix.strip().startswith(("**", "- "))
    ):
        leading = re.match(r"^(\s*(?:[-•*]\s+\*\*[^*]+?:\*\*\s*)?)", prefix)
        head = leading.group(1) if leading else ""
        if suffix and not suffix.startswith((" ", "\n")):
            if suffix.startswith("**"):
                suffix = "\n\n" + suffix
            elif suffix[0].isalpha() or suffix[0] in "ÇĞİÖŞÜçğıöşüâîû":
                ch = suffix[0]
                if ch.upper() == ch and ch.lower() != ch:
                    suffix = "\n\n" + suffix
                else:
                    suffix = " " + suffix
        return f"{head}{match.group(1)}{suffix}"
    return line


def _leading_inline_math(line: str) -> str:
    """Satır başındaki ``$…$`` (ardından yapışık metin olsa da)."""
    match = re.match(r"^(\$[^$\n]+\$)", (line or "").strip())
    return match.group(1) if match else ""


def _iter_inline_dollar_spans(text: str) -> list[re.Match[str]]:
    """Soldan sağa gerçek ``$…$`` aralıkları (prose üzerinden yanlış eşleşme yok)."""
    return list(re.finditer(r"\$[^$\n]+\$", text or ""))


def _inline_math_followed_by(text: str, pred) -> bool:
    """Kapanış ``$`` sonrası karakter ``pred`` ise True."""
    src = text or ""
    for match in _iter_inline_dollar_spans(src):
        end = match.end()
        if end < len(src) and pred(src[end]):
            return True
    return False


def _has_digit_glued_after_inline_math(text: str) -> bool:
    """``$x$0`` gibi yapışık rakam (``$8AA$ … $94$`` yanlış pozitif değil)."""
    return _inline_math_followed_by(text, str.isdigit)


def _strip_glued_digits_after_inline_math(text: str) -> str:
    """``$x$0`` yapışık rakamı sil; ``$a$, $27 =`` komşu matematiğe dokunma.

    Naif ``(\\$[^$]+\\$)\\d+`` deseni ``$54=…$, $27 =`` satırında ikinci
    ``$`` açılışını kapanış sanıp ``27``'yi yer; span iterasyonu kullan.
    """
    src = text or ""
    spans = _iter_inline_dollar_spans(src)
    if not spans:
        return src
    out: list[str] = []
    pos = 0
    for match in spans:
        out.append(src[pos : match.end()])
        rest = src[match.end() :]
        glued = re.match(r"(\d+)(?=\s|$)", rest)
        if glued:
            pos = match.end() + glued.end()
        else:
            pos = match.end()
    out.append(src[pos:])
    return "".join(out)


def _has_capital_glued_after_inline_math(text: str) -> bool:
    """``$x$Yaş`` gibi yapışık büyük harf (``$ABC$ olduğundan $A$`` değil)."""
    return _inline_math_followed_by(
        text, lambda ch: bool(re.match(r"[A-ZÇĞİÖŞÜ]", ch))
    )


def _split_math_glued_prose_on_line(line: str) -> str:
    """``$…$Yaş`` / ``$…$yaş`` → satır kır veya boşluk; aralıklı ``$A$ $B$`` dokunma."""
    src = line or ""
    if not src:
        return src
    out: list[str] = []
    pos = 0
    for match in _iter_inline_dollar_spans(src):
        out.append(src[pos : match.end()])
        end = match.end()
        if end < len(src):
            ch = src[end]
            if ch.isalpha() or ch in "ÇĞİÖŞÜçğıöşüâîû":
                if ch.upper() == ch and ch.lower() != ch:
                    out.append("\n\n")
                else:
                    out.append(" ")
        pos = match.end()
    out.append(src[pos:])
    return "".join(out)


_HPHANTOM_CMD_RE = re.compile(r"\\(?:hphantom|phantom)\s*\{[^{}]*\}")
_SHORT_MATH_ONLY_RE = re.compile(r"^\$[^$\n]{0,24}\$\s*$")
_COMPLETE_EQ_MATH_RE = re.compile(r"\$([^$\n]*=[^$\n]+)\$")


def _math_body_compact(body: str) -> str:
    return re.sub(r"\s+", "", (body or "").replace("\\", ""))


def _collapse_hphantom_glued_duplicate_line(line: str) -> str:
    """``$tam$ $parça$ $\\hphantom…$`` → ilk tam eşitlik."""
    spans = _iter_inline_dollar_spans(line)
    if len(spans) < 2:
        return line
    first = spans[0].group(0)
    if "=" not in first or len(first) < 12:
        return line
    body0 = _math_body_compact(first[1:-1])
    if len(body0) < 8:
        return line
    host_body = first[1:-1]
    prev_end = spans[0].end()
    for span in spans[1:]:
        between = line[prev_end : span.start()]
        prev_end = span.end()
        frag_body = span.group(0)[1:-1]
        frag = _math_body_compact(frag_body)
        if not frag or frag in {"=", "+", "-", "(", ")", "cdot", "times"}:
            continue
        # Prose ara (``. Rakamlar``) varsa echo değil — dokunma
        if between.strip() not in {"", ","}:
            return line
        if not _fragment_tokens_covered_by_host(frag_body, host_body):
            return line
    prose_before = line[: spans[0].start()]
    prose_after = line[spans[-1].end() :]
    if prose_after.strip().startswith("$"):
        prose_after = ""
    return (prose_before + first + prose_after).rstrip()


def _drop_short_math_fragments_after_equation(text: str) -> str:
    """Tam eşitlik satırından sonra gelen kısa ``$a$`` / ``$)$`` enkazını at."""
    lines = (text or "").split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        eq_hosts = [
            m.group(1)
            for m in _COMPLETE_EQ_MATH_RE.finditer(line)
            if len(m.group(1)) >= 8
        ]
        if not eq_hosts:
            i += 1
            continue
        j = i + 1
        while j < len(lines):
            nxt = lines[j].strip()
            if not nxt:
                j += 1
                continue
            if not _SHORT_MATH_ONLY_RE.match(nxt):
                break
            frag_body = nxt[1:-1]
            frag = _math_body_compact(frag_body)
            if not frag or any(
                _fragment_tokens_covered_by_host(frag_body, host) for host in eq_hosts
            ):
                j += 1
                continue
            break
        i = j
    return "\n".join(out)


def scrub_hphantom_math_debris(text: str) -> str:
    """``\\hphantom`` / parçalanmış dikey-math enkazını temizle.

    Ağır OCR/Gemini artığında tam anlamı yeniden yazmak mümkün olmayabilir;
    en azından phantom komutları, yapışık kopyalar ve kısa fragment koşuları iner.
    """
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src.strip():
        return src
    has_phantom = "hphantom" in src or "\\phantom" in src
    if not has_phantom and not _looks_like_fragmented_math_debris(src):
        return src

    src = _HPHANTOM_CMD_RE.sub("", src)
    src = re.sub(r"[ \t]{2,}", " ", src)

    cleaned_lines: list[str] = []
    for line in src.split("\n"):
        line = _collapse_hphantom_glued_duplicate_line(
            line.strip() if has_phantom else line
        )
        s = line.strip()
        if not s:
            cleaned_lines.append("")
            continue
        # Phantom-only satır artığı: `$=$` / `$ $` / `$+$`
        if re.fullmatch(r"\$\s*[=+\-().,\\cdot\s]*\$", s):
            continue
        # Yalnızca boş / operatör math artığı
        if _SHORT_MATH_ONLY_RE.match(s):
            body = s[1:-1].strip()
            if not body or body in {"=", "+", "-", "(", ")", ",", ".", "\\cdot", "\\times"}:
                continue
        cleaned_lines.append(line.rstrip() if has_phantom else line)

    src = "\n".join(cleaned_lines)
    src = _drop_short_math_fragments_after_equation(src)
    # Ardışık aynı satır tekrarı (tam eşitlik iki kez)
    deduped: list[str] = []
    for line in src.split("\n"):
        if deduped and line.strip() and line.strip() == deduped[-1].strip():
            continue
        deduped.append(line)
    src = "\n".join(deduped)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def _looks_like_fragmented_math_debris(text: str) -> bool:
    """Ardışık kısa ``$…$`` / ``$+$`` / ``$=$`` satırları (XPM bölünmüş toplam)."""
    streak = 0
    for line in (text or "").split("\n"):
        s = line.strip()
        if (
            _SHORT_MATH_ONLY_RE.match(s)
            or re.fullmatch(r"\$[=+\-0-9.\\{}\\\s]{0,28}\$", s)
        ) and len(s) <= 30:
            streak += 1
            if streak >= 3:
                return True
        elif s:
            streak = 0
    # Tek satırda denklem + yalnızca boşlukla ayrılmış kısa echo fragmentler
    for line in (text or "").split("\n"):
        spans = _iter_inline_dollar_spans(line)
        if len(spans) < 3 or "=" not in spans[0].group(0):
            continue
        host_body = spans[0].group(0)[1:-1]
        short = 0
        ok = True
        for k, sp in enumerate(spans[1:], start=1):
            between = line[spans[k - 1].end() : sp.start()]
            if between.strip() not in {"", ","}:
                ok = False
                break
            if len(sp.group(0)) <= 12 and _fragment_tokens_covered_by_host(
                sp.group(0)[1:-1], host_body
            ):
                short += 1
        if ok and short >= 2:
            return True
    return False



def _fragment_tokens_covered_by_host(frag_body: str, host_body: str) -> bool:
    """Kısa math fragment host ifadenin token'larıyla örtünüyor mu?

    ``3`` ⊂ ``12`` yanlış pozitifini engellemek için rakam/harf bütün token
    eşleşmesi kullanır (``1`` ⊂ ``1,3,5`` kabul; ``3`` ⊂ ``12`` red).
    """
    frag_c = _math_body_compact(frag_body)
    host_c = _math_body_compact(host_body)
    if not frag_c:
        return True
    if frag_c == host_c:
        return True
    host_nums = set(re.findall(r"\d+", host_c))
    host_letters = set(re.findall(r"[A-Za-z]+", host_c))
    frag_nums = re.findall(r"\d+", frag_c)
    frag_letters = re.findall(r"[A-Za-z]+", frag_c)
    if frag_nums or frag_letters:
        if any(n not in host_nums for n in frag_nums):
            return False
        if any(let not in host_letters for let in frag_letters):
            return False
        return True
    # Salt operatör / noktalama
    return all(ch in host_c for ch in frag_c if ch not in "\\")


def _collapse_math_token_echo_line(line: str) -> str:
    """``$2+4=6$ $2$ $+4$ $=6$`` / ``$Y=7$$Y=7$ $Y$`` → host ifadeleri koru.

    Aynı satırda birden fazla host+echo kümesi olabilir
    (``$2+4+1=7$ ... **$Y=7$$Y=7$**``); her kümeyi ayrı sıkıştırır.
    """
    spans = _iter_inline_dollar_spans(line)
    if len(spans) < 2:
        return line

    parts: list[str] = []
    pos = 0
    i = 0
    while i < len(spans):
        host = spans[i]
        parts.append(line[pos : host.start()])
        host_body = host.group(0)[1:-1]
        j = i + 1
        while j < len(spans):
            between = line[spans[j - 1].end() : spans[j].start()]
            if between.strip() not in {"",}:
                break
            if not _fragment_tokens_covered_by_host(
                spans[j].group(0)[1:-1], host_body
            ):
                break
            j += 1
        if j > i + 1:
            kept_body = re.sub(r"\\(=|\+)", r"\1", host_body)
            parts.append(f"${kept_body}$")
            pos = spans[j - 1].end()
            i = j
        else:
            parts.append(host.group(0))
            pos = host.end()
            i += 1
    parts.append(line[pos:])
    return "".join(parts).rstrip()


def _drop_math_token_echo_lines(text: str) -> str:
    """Tam ifadeden sonra gelen salt ``$1$`` / kopya satırlarını at.

    Prose taşıyan echo satırındaki ek metni korur (``$2+4=6$ 'dır.``).
    """
    lines = (text or "").split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = _collapse_math_token_echo_line(lines[i])
        spans = _iter_inline_dollar_spans(line)
        host_bodies = [s.group(0)[1:-1] for s in spans]
        out.append(line)
        if not host_bodies:
            i += 1
            continue

        j = i + 1
        while j < len(lines):
            nxt_raw = lines[j]
            if not nxt_raw.strip():
                j += 1
                continue
            collapsed = _collapse_math_token_echo_line(nxt_raw)
            nxt = collapsed.strip()
            nxt_spans = _iter_inline_dollar_spans(nxt)
            if not nxt_spans:
                break

            nxt_first = nxt_spans[0].group(0)[1:-1]
            matched_host = next(
                (
                    hb
                    for hb in host_bodies
                    if _math_body_compact(nxt_first) == _math_body_compact(hb)
                    or _fragment_tokens_covered_by_host(nxt_first, hb)
                ),
                None,
            )
            if matched_host is None:
                break

            rest_ok = all(
                _fragment_tokens_covered_by_host(s.group(0)[1:-1], nxt_first)
                for s in nxt_spans[1:]
            )
            if not rest_ok and len(nxt_spans) > 1:
                break

            nxt_pure = bool(re.fullmatch(r"\$[^$\n]+\$", nxt))
            # Salt math kopya / kısa fragment → at
            if nxt_pure:
                j += 1
                continue

            # Prose'lu echo: önceki satırdaki aynı math'ten sonra gelen ek metni birleştir
            prev = out[-1]
            prev_spans = _iter_inline_dollar_spans(prev)
            if not prev_spans:
                break
            # Son host span ile eşleşen
            host_span = None
            for sp in reversed(prev_spans):
                if _math_body_compact(sp.group(0)[1:-1]) == _math_body_compact(
                    matched_host
                ) or _math_body_compact(sp.group(0)[1:-1]) == _math_body_compact(
                    nxt_first
                ):
                    host_span = sp
                    break
            if host_span is None:
                host_span = prev_spans[-1]

            trailing = nxt[nxt_spans[-1].end() :]
            # Önceki satırda host'tan sonra zaten metin varsa yalnızca salt-tekrarı at
            prev_after = prev[host_span.end() :]
            if prev_after.strip():
                # Echo satırındaki yeni prose'u ekle (yoksa at)
                if trailing.strip() and trailing.strip() not in prev_after:
                    out[-1] = prev.rstrip() + trailing
                j += 1
                continue
            # Host'tan sonra boş → echo prose'unu taşı
            prefix = nxt[: nxt_spans[0].start()]
            # prefix yalnızca boşluk/parantez artığıysa yoksay
            out[-1] = prev[: host_span.end()] + trailing
            if prefix.strip() and prefix.strip() not in out[-1]:
                # Açılış parantezi gibi prefix önceki satırda yoksa satır başına taşıma
                # (genelde host zaten ``(`` ile başlar)
                pass
            j += 1
            continue
        i = j
    return "\n".join(out)


def looks_like_math_token_expansion_debris(text: str) -> bool:
    """Denklem + token kopyası / bitişik ``$Y=7$$Y=7$`` yapıştırması."""
    src = text or ""
    if re.search(r"\$[^$\n]+\$\$[^$\n]+\$", src):
        return True
    for line in src.split("\n"):
        spans = _iter_inline_dollar_spans(line)
        if len(spans) < 3:
            continue
        host_body = spans[0].group(0)[1:-1]
        first_c = _math_body_compact(host_body)
        if len(first_c) < 2:
            continue
        short = 0
        ok = True
        for k, sp in enumerate(spans[1:], start=1):
            between = line[spans[k - 1].end() : sp.start()]
            if between.strip() not in {"", ","}:
                ok = False
                break
            if _fragment_tokens_covered_by_host(sp.group(0)[1:-1], host_body):
                short += 1
        if ok and short >= 2:
            return True
    # Üst üste salt kısa math-only token satırları (liste expansion)
    streak = 0
    for line in src.split("\n"):
        s = line.strip()
        if _SHORT_MATH_ONLY_RE.match(s) and len(s) <= 30:
            streak += 1
            if streak >= 3:
                return True
        elif s:
            streak = 0
    return False


def scrub_math_token_expansion_debris(text: str) -> str:
    """Google Docs denklem token-expansion / bitişik kopya enkazını sadeleştir."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src.strip() or not looks_like_math_token_expansion_debris(src):
        return src

    cleaned: list[str] = []
    for line in src.split("\n"):
        cleaned.append(_collapse_math_token_echo_line(line))
    src = "\n".join(cleaned)
    src = _drop_math_token_echo_lines(src)

    deduped: list[str] = []
    for line in src.split("\n"):
        if deduped and line.strip() and line.strip() == deduped[-1].strip():
            continue
        deduped.append(line)
    src = "\n".join(deduped)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def looks_like_glued_duplicate_math(text: str) -> bool:
    """``$x + 80x+ 80$`` / ``$x = 30x=$`` / ``$xx$`` / ``$D$ $=1$`` yapışması."""
    src = text or ""
    if re.search(r"\\[=+]", src):
        return True
    if re.search(r"\$([a-zA-Z])\1\$", src):
        return True
    # ``x = 30x=`` (zincir ``= 8k =`` değil)
    if re.search(r"([a-zA-Z])\s*=\s*-?\d+\1\s*=", src):
        return True
    # ``x + 80x+ 80x`` — en az iki yapışık tekrar (``k + 2k`` tek başına değil)
    if re.search(
        r"(?<![0-9])([a-zA-Z])\s*\+\s*\d+\1\s*\+\s*\d+\1",
        src,
    ):
        return True
    if re.search(
        r"(\\frac\{[^{}]+\}\{[^{}]+\}\s*=\s*\\frac\{[^{}]+\}\{[^{}]+\})\1",
        src,
    ):
        return True
    if re.search(r"(\\frac\{[^{}]+\}\{[^{}]+\})\1", src):
        return True
    # ``$D$ $=1$`` / ``$,\" $`` XPM harf–eşitlik parçalanması
    if re.search(r"\$[A-Za-z]\$\s*\$=", src):
        return True
    if re.search(r"\$,\\?\"\s*\$", src):
        return True
    return False


def _repair_one_glued_math_body(body: str) -> str | None:
    """Tek ``$…$`` gövdesini sadeleştir; bakılamazsa None."""
    raw = (body or "").strip()
    if not raw:
        return None

    # $xx$ → $x$
    m_xx = re.fullmatch(r"([a-zA-Z])\1", raw)
    if m_xx:
        return m_xx.group(1)

    cleaned = re.sub(r"\\(=|\+)", r"\1", raw)

    # x + 80x+ 80x + 80 → x + 80
    m_sum = re.match(
        r"^([a-zA-Z]\s*\+\s*\d+)(?:\s*(?:\1|[a-zA-Z]\s*\+\s*\d+))+$",
        cleaned,
    )
    if m_sum:
        return m_sum.group(1)

    # x = 30x= 30…
    m_eq = re.match(
        r"^([a-zA-Z]\s*=\s*-?\d+)(?:\s*(?:\1|[a-zA-Z]\s*=\s*-?\d+))+$",
        cleaned,
    )
    if m_eq:
        return m_eq.group(1)

    # (x + 80) - 30 = x + 50(x+80)-…
    m_paren = re.match(
        r"^(\([^)]+\)\s*[+\-]\s*\d+\s*=\s*[a-zA-Z]\s*[+\-]\s*\d+)",
        cleaned,
    )
    if m_paren and len(cleaned) > len(m_paren.group(1)) + 4:
        return m_paren.group(1)

    # (x + 80) + 20 = x + 100…
    m_paren2 = re.match(
        r"^(\([^)]+\)\s*\+\s*\d+\s*=\s*[a-zA-Z]\s*\+\s*\d+)",
        cleaned,
    )
    if m_paren2 and len(cleaned) > len(m_paren2.group(1)) + 4:
        return m_paren2.group(1)

    # Aynı frac=frac tekrarı
    m_fr = re.match(
        r"^(\\frac\{[^{}]+\}\{[^{}]+\}\s*=\s*\\frac\{[^{}]+\}\{[^{}]+\})(?:\1)+$",
        cleaned,
    )
    if m_fr:
        return m_fr.group(1)

    # Birden fazla \\frac yapışığı: son/basit denklemi tut
    if cleaned.count("\\frac") >= 3:
        eqs = re.findall(
            r"\\frac\{[^{}]+\}\{[^{}]+\}\s*=\s*\\frac\{[^{}]+\}\{[^{}]+\}",
            cleaned,
        )
        if eqs:
            # En kısa / en sade (metin \text içermeyen) tercihi
            plain = [e for e in eqs if r"\text" not in e]
            return (plain or eqs)[0]

    if cleaned != raw:
        return cleaned
    return None


def scrub_glued_duplicate_math(text: str) -> str:
    """Yapışık tekrarlı inline/display math enkazını sadeleştir."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src.strip() or not looks_like_glued_duplicate_math(src):
        return src

    def fix_inline(match: re.Match[str]) -> str:
        repaired = _repair_one_glued_math_body(match.group(1))
        if repaired is None:
            return match.group(0)
        return f"${repaired}$"

    def fix_display(match: re.Match[str]) -> str:
        repaired = _repair_one_glued_math_body(match.group(1).strip())
        if repaired is None:
            return match.group(0)
        return f"$${repaired}$$"

    src = re.sub(r"\$\$([\s\S]+?)\$\$", fix_display, src)
    src = re.sub(r"(?<!\$)\$([^$\n]+)\$", fix_inline, src)
    # ``$D$ $=1$`` / ``$C$ $=2$`` → ``$D=1$`` / ``$C=2$``
    src = re.sub(r"\$([A-Za-z])\$\s*\$=\s*", r"$\1=", src)
    # ``$,\" $`` / ``$\displaystyle ," $`` XPM tırnak/displaystyle enkazı
    # (yalnızca tırnak/virgül sinyali — boş `$ $` sınırını yutma)
    src = re.sub(r"\$\\displaystyle\s*,\\?\"\s*\$", "", src)
    src = re.sub(r"\$,\\?\"\s*\$", "", src)
    src = re.sub(r"\$,\"\s*\$", "", src)
    src = re.sub(r"[ \t]{2,}", " ", src)
    # Satır: ``$D=1, C=2, B=5$ $D$ $=1$ $,\" $ …``
    fixed_lines: list[str] = []
    for line in src.split("\n"):
        fixed_lines.append(_collapse_assignment_letter_debris_line(line))
    src = "\n".join(fixed_lines)
    # ``$C$\n$=2$`` → ``$C=2$``
    src = merge_split_inline_dollar_math(src)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def _collapse_assignment_letter_debris_line(line: str) -> str:
    """``$D=1, C=2, B=5$ $D$ $=1$ $,\" $ $C$ $=2$`` → ilk atama listesi."""
    spans = _iter_inline_dollar_spans(line)
    if len(spans) < 2:
        return line

    def _is_letter_eq_frag(body: str, first_body: str, first_compact: str) -> bool:
        b = (body or "").strip()
        if re.fullmatch(r"[A-Za-z]", b):
            return True
        if re.fullmatch(r"=?\\?\s*-?\d+", b):
            return True
        if re.fullmatch(r"(?:\\displaystyle\s*)?[,\"'\\=\s]+", b):
            return True
        if re.fullmatch(r"[A-Za-z]\s*=\s*-?\d+", b):
            # Liste sonrası tek atama (değer yanlış olsa bile) XPM tekrarıdır
            if "," in first_body or first_body.count("=") >= 2:
                return True
            return _math_body_compact(b) in first_compact
        return False

    # Atama listesi ilk ``$…$`` olmak zorunda değil (önünde ``$= 125$`` olabilir)
    for i, sp in enumerate(spans[:-1]):
        first = sp.group(0)
        first_body = first[1:-1].strip()
        if not re.search(r"[A-Za-z]\s*=\s*-?\d+", first_body):
            continue
        # Liste (virgül / birden fazla =) veya tek atama + salt enkaz
        rest = spans[i + 1 :]
        first_compact = _math_body_compact(first_body)
        is_list = "," in first_body or first_body.count("=") >= 2
        if not all(
            _is_letter_eq_frag(s.group(0)[1:-1], first_body, first_compact)
            for s in rest
        ):
            # Kısmi: yalnızca ardışık enkaz önekini kes
            j = 0
            while j < len(rest) and _is_letter_eq_frag(
                rest[j].group(0)[1:-1], first_body, first_compact
            ):
                j += 1
            if j == 0:
                continue
            if not is_list and j < len(rest):
                continue
            return (
                line[: sp.start()] + first + line[rest[j - 1].end() :]
            ).rstrip()
        return (
            line[: sp.start()] + first + line[rest[-1].end() :]
        ).rstrip()
    return line


def _next_nonempty(lines: list[str], start: int) -> tuple[int, str]:
    j = start
    while j < len(lines) and not lines[j].strip():
        j += 1
    if j >= len(lines):
        return -1, ""
    return j, lines[j].strip()


def _strip_speech_preserving_math(line: str) -> str:
    """Satırdaki ``$…$`` koru; İngilizce konuşma token'larını satır nuke etmeden sil."""
    holders: list[str] = []

    def stash(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"§§X{len(holders) - 1}§§"

    protected = re.sub(r"\$[^$\n]+\$", stash, line)
    if _GOOGLE_SPEECH_SIGNAL_RE.search(protected) or _XPM_SPEECH_GLUE_RE.search(
        protected
    ):
        # Konuşma ağırlıklı ve matematik yoksa satırı düş
        if not holders and (
            re.search(r"\bequals\b|(?<!\\)\bimplies\b|\bfour-thirds\b", protected, re.I)
            or (
                re.search(r"\b(?:cap|cross|plus|minus|space)\b", protected, re.I)
                and len(re.findall(r"[A-Za-z]{3,}", protected)) >= 2
            )
        ):
            return ""
        protected = _XPM_SPEECH_GLUE_RE.sub("", protected)
        protected = re.sub(
            r"\b(?:equals|(?<!\\)implies|cross|four-thirds|end-fraction|"
            r"open paren|close paren|cap|plus|minus|space)\b",
            "",
            protected,
            flags=re.I,
        )
        protected = re.sub(r"[ \t]{2,}", " ", protected).strip()
        # Konuşma scrub sonrası yalnız düz formül + rakam artığı kaldıysa satırı düş
        if not holders and (
            not protected
            or re.fullmatch(
                r"[A-Za-z0-9+\-×÷=⇒→().,\s]{0,40}",
                protected,
            )
        ):
            return ""
        # ``M+3x=50(1. Denklem) M 3 x 50 (1. Denklem)`` — konuşma kopyası tekrarı
        if holders and re.search(
            r"\)\s*[A-Za-z0-9].{0,40}\(\d+\.\s*Denklem\)",
            protected,
            re.I,
        ):
            protected = re.split(r"\)\s+(?=[A-Za-z])", protected, maxsplit=1)[0] + ")"
            protected = protected.strip()
    restored = re.sub(
        r"§§X(\d+)§§",
        lambda m: holders[int(m.group(1))]
        if int(m.group(1)) < len(holders)
        else m.group(0),
        protected,
    )
    return restored


def scrub_google_math_speech_debris(text: str) -> str:
    """XPM sonrası kalan İngilizce konuşma / çift düz+LaTeX satırlarını temizle."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src.strip():
        return src
    # Mathematical Alphanumeric (𝑀, 𝑥, …) → ASCII — sinyal ve eşleşme için.
    if re.search(r"[\U0001D400-\U0001D7FF]", src):
        src = unicodedata.normalize("NFKC", src)
    if not (
        _GOOGLE_SPEECH_SIGNAL_RE.search(src)
        or _XPM_SPEECH_GLUE_RE.search(src)
        or re.search(r"[𝑥𝑋]", src)
        or re.search(r"(?<=\d)\n\d+\$", src)
        or re.search(r"(?i)\bMcap\b|\bover\b.*\bend-fraction\b", src)
        or _has_digit_glued_after_inline_math(src)
        or re.search(r"yaşındadır", src, re.I)
        or re.search(r"kmx\s*\d", src, re.I)
    ):
        return src

    # F3 fix: satır nuke yerine matematik korumalı scrub
    pre: list[str] = []
    for line in src.split("\n"):
        cleaned = _strip_speech_preserving_math(line)
        if cleaned.strip() or not line.strip():
            pre.append(cleaned)
    src = "\n".join(pre)

    src = re.sub(r"(?<=\d)(?:four-thirds|thirds)\b", "", src, flags=re.I)
    src = re.sub(r"(?i)\b([A-Za-z])cap\s*\1\b", r"$\1$", src)
    src = re.sub(r"\bxx\s*[𝑥𝑋xX]\b", "x", src)
    src = re.sub(r"[𝑥𝑋]", "x", src)
    # ``43\n43$\frac`` → ``$\frac``
    src = re.sub(r"(?<!\d)(\d+)\n\1\$", "$", src)
    # ``x$x$`` / ``M$M$`` → ``$x$``
    src = re.sub(r"(?<![A-Za-z\\$])([A-Za-z])\s*\$\1\$", r"$\1$", src)
    # ``$…$0`` yapışık rakam artığı (``$a$, $27 =`` komşu math korunur)
    src = _strip_glued_digits_after_inline_math(src)
    # Düz satır + hemen ardından aynı içeriğin $…$ hali: düz satırı düş
    lines = src.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        plain = line.strip()
        # Kısa sembol artığı koşusu → sonraki $…$ satırına kadar atla
        if _XPM_MATH_FRAG_LINE_RE.match(plain or ""):
            j = i
            while j < len(lines) and (
                not lines[j].strip() or _XPM_MATH_FRAG_LINE_RE.match(lines[j].strip())
            ):
                j += 1
            if j > i and j < len(lines) and _leading_inline_math(lines[j]):
                i = j
                continue
        _nxt_i, math = _next_nonempty(lines, i + 1)
        # ``14.\n39\n$…$`` — ondalık kırığı atla
        scan = _nxt_i
        while scan >= 0 and re.fullmatch(r"\d+\.?", math or ""):
            scan, math = _next_nonempty(lines, scan + 1)
        if (
            plain
            and _leading_inline_math(math)
            and not plain.startswith("$")
            and (
                re.sub(r"\s+", "", plain)
                == re.sub(r"[\s$\\*]", "", _leading_inline_math(math))[
                    : max(len(plain) // 2, 8)
                ]
                or _plain_formula_lookalike(plain)
                or (
                    len(plain) <= 80
                    and "=" in plain
                    and re.search(r"\d", plain)
                    and not plain.startswith(("**", "- "))
                )
            )
        ):
            # Düz formül kopyası → sonraki $…$ satırını tut
            i += 1
            continue
        # Ondalık kırığı ``14.`` / ``39`` (sonraki $…$ varsa)
        if re.fullmatch(r"\d+\.?", plain or ""):
            scan, nxt_math = _next_nonempty(lines, i + 1)
            while scan >= 0 and re.fullmatch(r"\d+\.?", nxt_math or ""):
                scan, nxt_math = _next_nonempty(lines, scan + 1)
            if _leading_inline_math(nxt_math):
                i += 1
                continue
        # ``…km$x=…$`` yapışık → satır kır (kapanış ``$`` sonrası değil)
        line = re.sub(
            r"(?<!\$)([a-zçğıöşü0-9).])\$(?=\\|[A-Za-z0-9])",
            r"\1\n\n$",
            line,
            flags=re.I,
        )
        line = _drop_plain_prefix_before_inline_math(line)
        # ``$…$**3. Başlık`` → satır kır; ``$…$**yaş`` → boşluk
        line = re.sub(
            r"(\$[^$\n]+\$)\*\*(?=\d+\.|\s*[A-ZÇĞİÖŞÜ])",
            r"\1\n\n**",
            line,
        )
        line = re.sub(r"(\$[^$\n]+\$)\*\*(?=\S)", r"\1 ", line)
        line = _split_math_glued_prose_on_line(line)
        # ``$x$ yaşındadır)`` / ``$x$ yaşındadır-`` — annotation artığı
        line = re.sub(
            r"(\$[^$\n]+\$)\s*yaşındadır\.?\)?-?",
            r"\1",
            line,
            flags=re.I,
        )
        line = re.sub(
            r"(\$[^$\n]+\$)\s+([a-zçğıöşüâîû]{3,})\)(?=\s*[-—.]|\s*$)",
            r"\1 \2",
            line,
            flags=re.I,
        )
        line = re.sub(r"\b([a-zçğıöşüâîû]{4,})\)(?=-)", r"\1", line, flags=re.I)
        # ``Analizi-`` / ``Adımları-`` başlık tire artığı
        line = re.sub(
            r"([A-Za-zÇĞİÖŞÜçğıöşüâîû]{3,})-\s*$",
            r"\1",
            line,
        )
        # ``104 kmx 78 26 4 104 km`` / ``$x$):x=78…kmx 78`` düz kopya artığı
        line = re.sub(
            r"(?:\$[^$\n]+\$\)?:?)?[A-Za-z]?=?[\d×xX*+\-./]+\s*kmx?\s*[\d\s]+km\b",
            "",
            line,
        )
        line = re.sub(r"\(xx?\)?\s*$", "", line)
        # Orphan ``**x`` / ``**M`` before math already extracted
        if re.fullmatch(r"\*\*[A-Za-z]\s*", plain or ""):
            i += 1
            continue
        out.append(line)
        i += 1
    src = "\n".join(out)
    # Orphan konuşma devamı / yarım satır / sahte $prose
    cleaned_lines: list[str] = []
    for line in src.split("\n"):
        s = line.strip()
        if re.fullmatch(r"[,.]?\d{1,3}", s):
            continue
        if re.fullmatch(r"[,.]", s):
            continue
        if re.match(r"^\d+\$", s) and s.count("$") == 1:
            continue
        if s.startswith("$") and s.count("$") == 1 and len(s) < 12:
            continue
        if (
            s.startswith("$")
            and not s.startswith("$\\")
            and re.match(r"^\$[a-zçğıöşüâîû ]", s, flags=re.I)
            and not re.search(r"[\\=+\-^_{×÷]", s)
        ):
            continue
        if re.search(r"\([A-Z]$", s) and len(s) < 40:
            continue
        # ``(xx`` / ``(x`` artığı
        if re.fullmatch(r"\(x{1,2}", s, flags=re.I):
            continue
        cleaned_lines.append(line)
    # Düz kopya tekrarı (boş satır aralıklı) + formül → $…$
    deduped: list[str] = []
    i = 0
    cl = cleaned_lines
    while i < len(cl):
        cur = cl[i].strip()
        nxt_i, nxt = _next_nonempty(cl, i + 1)
        nxt2_i, nxt2 = _next_nonempty(cl, nxt_i + 1) if nxt_i >= 0 else (-1, "")
        if (
            cur
            and nxt
            and cur == nxt
            and not cur.startswith("$")
            and _leading_inline_math(nxt2)
        ):
            i += 1
            continue
        if cur and _leading_inline_math(nxt) and not cur.startswith("$") and (
            _plain_formula_lookalike(cur)
            or (
                len(cur) <= 80
                and "=" in cur
                and re.search(r"\d", cur)
                and not cur.startswith(("**", "- "))
            )
        ):
            i += 1
            continue
        deduped.append(cl[i])
        i += 1
    src = "\n".join(deduped)
    # ``×60`` / ``=54`` / ``dakika`` artıkları — sonraki $…$ öncesi
    lines = src.split("\n")
    out2: list[str] = []
    i = 0
    while i < len(lines):
        plain = lines[i].strip()
        if _XPM_MATH_FRAG_LINE_RE.match(plain or "") or plain in {
            "dakika",
            "saat",
            "km",
        }:
            j = i
            while j < len(lines) and (
                not lines[j].strip()
                or _XPM_MATH_FRAG_LINE_RE.match(lines[j].strip())
                or lines[j].strip() in {"dakika", "saat", "km"}
            ):
                j += 1
            if j > i and j < len(lines) and lines[j].strip().startswith("$"):
                i = j
                continue
        out2.append(lines[i])
        i += 1
    src = "\n".join(out2)
    # ``$…$👶 Sonuç`` / ``}$👶``
    src = re.sub(r"(\$[^$\n]*\$)\s*[👶📌🚨]", r"\1\n\n", src)
    src = re.sub(r"([^\s\n])([👶📌🚨])", r"\1\n\n\2", src)
    # ``$x$):x=78×43=26×4`` düz formül öneki — sonraki $…$ varsa satırı düş
    lines = src.split("\n")
    out3: list[str] = []
    i = 0
    while i < len(lines):
        plain = lines[i].strip()
        if re.match(r"^\$[^$\n]+\$\)?:[A-Za-z0-9]", plain or ""):
            nxt_i, nxt = _next_nonempty(lines, i + 1)
            if _leading_inline_math(nxt):
                i += 1
                continue
        # ``…yaşı)2 M 64 M 32 (Annenin`` — parantez sonrası digit-letter kopya
        if re.search(r"\)\d+\s+[A-Za-z]\s+\d+", plain or ""):
            plain = re.split(r"(?<=\))\d+\s+[A-Za-z]", plain, maxsplit=1)[0]
            lines[i] = plain
        if re.fullmatch(
            r"(?:\d+\s+[A-Za-z]\s+)+\d+(?:\s*\([^)]*\))?",
            plain or "",
        ):
            nxt_i, nxt = _next_nonempty(lines, i + 1)
            if _leading_inline_math(nxt):
                i += 1
                continue
        out3.append(lines[i])
        i += 1
    src = "\n".join(out3)
    src = re.sub(r"[ \t]{2,}", " ", src)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def strip_google_docs_xpm_paste(text: str) -> str:
    """Google Docs denklem yapıştırması: TgQPHd/XPM SVG → ``data-xpm-latex`` / sil."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src or not _GOOGLE_XPM_SIGNAL_RE.search(src):
        return scrub_google_math_speech_debris(src)

    def repl_blob(match: re.Match[str]) -> str:
        return _latex_from_xpm_blob(match.group(0))

    src = _TGQPHD_BLOB_RE.sub(repl_blob, src)
    src = _XPM_SIDE_MARKER_RE.sub("", src)
    # Kalan kapanmamış / boş TgQPHd
    src = re.sub(r"<!--TgQPHd[^<\n]*", "", src, flags=re.I)
    return scrub_google_math_speech_debris(src)


def strip_paste_fragment_markers(text: str) -> str:
    """Google/panel yapıştırmasında kalan ``<!--TgQPHd...`` / Fragment artıklarını temizler."""
    src = text or ""
    if looks_like_word_mso_paste_debris(src):
        src = scrub_word_mso_paste_debris(src)
    if _GOOGLE_XPM_SIGNAL_RE.search(src):
        src = strip_google_docs_xpm_paste(src)
    if looks_like_xpm_html_attribute_debris(src):
        src = scrub_xpm_html_attribute_debris(src)
    if looks_like_docs_annotation_token_debris(src):
        src = scrub_docs_annotation_token_debris(src)
    if "<!--" not in src and "- →" not in src:
        return src
    for pattern in _PASTE_FRAGMENT_MARKER_RES:
        src = pattern.sub("", src)
    return src.replace("- →", "")


def looks_like_word_mso_paste_debris(text: str) -> bool:
    """Word ``<!--[if gte mso`` / ``@font-face`` / ``mso-`` stil enkazı."""
    return bool(_WORD_MSO_SIGNAL_RE.search(text or ""))


def scrub_word_mso_paste_debris(text: str) -> str:
    """Word MSO conditional comment + font/style definition dökümünü sil."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not looks_like_word_mso_paste_debris(src):
        return src
    out = src
    for _ in range(8):
        nxt = _MSO_IF_BLOCK_RE.sub("", out)
        if nxt == out:
            break
        out = nxt
    out = _MSO_IF_OPEN_RE.sub("", out)
    out = _MSO_ENDIF_RE.sub("", out)
    out = _WORD_CSS_DEBRIS_RE.sub("", out)
    return re.sub(r"\n{3,}", "\n\n", out).strip()


def looks_like_xpm_html_attribute_debris(text: str) -> bool:
    """``$=\" draggable=$`` gibi yarım XPM/HTML sızıntısı."""
    return bool(_XPM_HTML_ATTR_DEBRIS_RE.search(text or ""))


def scrub_xpm_html_attribute_debris(text: str) -> str:
    """Yarım kalmış ``draggable=`` / ``$=\"`` HTML artığını sil."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not looks_like_xpm_html_attribute_debris(src):
        return src
    src = re.sub(
        r'\$\s*=\s*\\?"?\s*draggable\s*=\s*(?:\\?"?(?:false|true)\\?"?\s*)?\$?',
        "",
        src,
        flags=re.I,
    )
    src = re.sub(
        r'\bdraggable\s*=\s*\\?"?(?:false|true)?\\?"?',
        "",
        src,
        flags=re.I,
    )
    src = re.sub(
        r'\brole\s*=\s*\\?"?presentation\\?"?',
        "",
        src,
        flags=re.I,
    )
    src = re.sub(
        r'\baria-hidden\s*=\s*\\?"?(?:true|false)?\\?"?',
        "",
        src,
        flags=re.I,
    )
    src = re.sub(
        r'\bdata-xpm-[a-z0-9-]+\s*=\s*\\?"[^"]*\\?"',
        "",
        src,
        flags=re.I,
    )
    src = re.sub(r'\$\s*=\s*\\?"\s*', "", src)
    # ``$120 + 180 =$ $120$ $+ 180$`` → ilk eşitliği koru, kısa fragmentleri at
    src = _collapse_split_sum_fragments(src)
    src = re.sub(r"[ \t]{2,}", " ", src)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def looks_like_docs_annotation_token_debris(text: str) -> bool:
    """Google Docs öneri/annotation JSON dump'ı (``,"66":0}],0,0,null…``)."""
    src = text or ""
    return bool(
        _DOCS_ANNOTATION_TOKEN_DEBRIS_RE.search(src)
        or _DOCS_ANNOTATION_ID_TAIL_RE.search(src)
    )


def scrub_docs_annotation_token_debris(text: str) -> str:
    """Yapışık Docs annotation / suggestion token dizisini sil."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not looks_like_docs_annotation_token_debris(src):
        return src
    src = _DOCS_ANNOTATION_TOKEN_DEBRIS_RE.sub("", src)
    src = _DOCS_ANNOTATION_ID_TAIL_RE.sub("", src)
    # ``kelime  :**`` boşluklarını sadeleştir
    src = re.sub(r"[ \t]{2,}", " ", src)
    src = re.sub(r" +(:\*\*)", r"\1", src)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def _collapse_split_sum_fragments(text: str) -> str:
    """``$120 + 180 =$`` sonrası ``$120$`` / ``$+ 180$`` / ``$=$`` enkazını düş."""
    lines = (text or "").split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Satır içi: tam denklem + kısa parçalar
        spans = _iter_inline_dollar_spans(line)
        if len(spans) >= 2:
            first = spans[0].group(0)
            if "=" in first and len(first) >= 8:
                bodies = [_math_body_compact(s.group(0)[1:-1]) for s in spans[1:]]
                first_body = _math_body_compact(first[1:-1])
                if all(
                    (not b)
                    or b in {"=", "+", "-"}
                    or b in first_body
                    or first_body.startswith(b.rstrip("="))
                    for b in bodies
                ):
                    prose_before = line[: spans[0].start()]
                    prose_after = line[spans[-1].end() :]
                    # draggable artığı sonrası kalın sonuç: **300 km**
                    line = (prose_before + first + prose_after).rstrip()
        out.append(line)
        # Sonraki kısa math-only satırları at (bölünmüş toplam)
        if re.search(r"\$[^$\n]*[=+][^$\n]*\$", line) or line.strip().endswith("=$"):
            j = i + 1
            while j < len(lines):
                nxt = lines[j].strip()
                if not nxt:
                    j += 1
                    continue
                if _SHORT_MATH_ONLY_RE.match(nxt) or re.fullmatch(
                    r"\$[=+\-0-9.\\{}\\\s]{0,24}\$", nxt
                ):
                    j += 1
                    continue
                break
            i = j
            continue
        i += 1
    return "\n".join(out)


def normalize_markup(text: str) -> str:
    """math-render.js normalizeMarkup (+ HTML yedek dönüşümü)."""
    src = (
        _decode_entities(text or "")
        .replace("\r\n", "\n")
        .replace("\r", "\n")
    )
    src = _ZWSP_RE.sub("", src)
    src = strip_paste_fragment_markers(src)
    src = src.replace("＊", "*").replace("＿", "_")
    src = re.sub(r"\$\\(?:long)?rightarrow\$", "→", src)
    src = src.replace(r"$\to$", "→")
    src = re.sub(r"[ \t]*->[ \t]*", " → ", src)
    src = re.sub(r"<br\s*/?>", "\n", src, flags=re.I)
    src = re.sub(r"</p\s*>", "\n\n", src, flags=re.I)
    src = re.sub(r"<p\b[^>]*>", "", src, flags=re.I)
    src = re.sub(r"</div\s*>", "\n", src, flags=re.I)
    src = re.sub(r"<div\b[^>]*>", "", src, flags=re.I)
    src = _replace_simple_html_tags(src)
    src = demote_block_underline_markup(src)
    src = tighten_markdown_markers(src)
    src = _ensure_markdown_exterior_spaces(src)
    src = _SPLIT_BOLD_RE.sub(r"**\1\2**", src)
    src = re.sub(r"^\s*\*\*\s*$", "", src, flags=re.MULTILINE)
    src = re.sub(r"^\s*__\s*$", "", src, flags=re.MULTILINE)
    return src.strip()


def merge_split_inline_dollar_math(text: str) -> str:
    """Panelde Enter ile bölünmüş `$Y\\n= 7$` → `$Y = 7$`."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src:
        return src
    display: list[str] = []
    inline: list[str] = []

    def stash_display(match: re.Match[str]) -> str:
        display.append(match.group(0))
        return f"§§D{len(display) - 1}§§"

    def stash_inline(match: re.Match[str]) -> str:
        inline.append(match.group(0))
        return f"§§I{len(inline) - 1}§§"

    src = re.sub(r"\$\$[\s\S]+?\$\$", stash_display, src)
    src = re.sub(r"\$[^$\n]+\$", stash_inline, src)
    prev = None
    while prev != src:
        prev = src
        src = re.sub(
            r"\$([^$\n]*)\n(\s*[^$\n]+)\$",
            lambda m: (
                f"${m.group(1).strip()} {m.group(2).strip()}$"
                if m.group(1).strip()
                else f"${m.group(2).strip()}$"
            ),
            src,
        )
    src = re.sub(
        r"§§I(\d+)§§",
        lambda m: inline[int(m.group(1))] if int(m.group(1)) < len(inline) else m.group(0),
        src,
    )
    src = re.sub(
        r"§§D(\d+)§§",
        lambda m: display[int(m.group(1))] if int(m.group(1)) < len(display) else m.group(0),
        src,
    )
    return src


def _protect_math_spans(text: str, holders: list[str]) -> str:
    """$...$ / $$...$$ / \\(...\\) / \\[...\\] bloklarını yer tutucu yap."""

    def repl(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"§§M{len(holders) - 1}§§"

    return re.sub(
        r"\$\$[\s\S]+?\$\$|"
        r"\$[^$\n]+\$|"
        r"\\\([\s\S]+?\\\)|"
        r"\\\[[\s\S]+?\\\]",
        repl,
        text,
    )


_ITALIC_QUOTE_TRAIL_RE = re.compile(r'\*("[^"\n]+")[ \t]+\*(?!\*)')
_ITALIC_QUOTE_LEAD_RE = re.compile(r'(?<=[^\s*])\*[ \t]+("[^"\n]+")\*')
_DIGER_SECENEKLER_GLUE_RE = re.compile(
    r"(?:\*\*)?\s*(Diğer Seçenekler(?:in)?(?:\s+Neden Olmaz\??|\s+Elenme Nedenleri))\s*"
    r"(?:\*\*)?\s*"
    r"(?=(?:[-•*◦○–—]\s*)?(?:\*\*)?\s*[A-E]\s*\)\s*(?:\*\*)?)",
    re.IGNORECASE,
)
_GLUED_OPTION_LETTER_RE = re.compile(
    r"(?<=[.!?:;]|[a-zçğıöşüâîû”\"'])(?:\s*\*\*)?\s*(?=[A-E]\)\s)"
)
_GLUED_BOLD_LETTER_RE = re.compile(
    r"(?<!\n)(?:\s*[-•*◦○–—])?\s*\*\*\s*([A-E])\s*\)\s*\*\*\s*"
)
_LINE_BOLD_LETTER_RE = re.compile(
    r"^[ \t]*[-•*◦○–—]?\s*\*\*\s*([A-E])\s*\)\s*\*\*\s*",
    re.MULTILINE,
)
_OPTION_TITLE_BODY_GLUE_RE = re.compile(
    r"([A-E]\)[^\n*]{3,80}?):\*\*[ \t]+(?=[A-ZÇĞİÖŞÜÂÎÛ\"“«])"
)
_DIGER_SECENEKLER_LINE_RE = re.compile(
    r"^(?:\*\*)?(Diğer Seçenekler(?:in)?(?:\s+Neden Olmaz\??|\s+Elenme Nedenleri)):?(?:\*\*)?$",
    re.IGNORECASE,
)
_SECENEK_HEADER_INLINE_RE = re.compile(
    r"\*\*((?:I\.\s+)?[^*\n]+?\([A-E]\s+seçeneği\)\s*:)\*\*",
    re.IGNORECASE,
)
_SECENEK_HEADER_LOOSE_RE = re.compile(
    r"\*\*\s+((?:I\.\s+)?[^*\n]+?\([A-E]\s+seçeneği\)\s*:)\*\*",
    re.IGNORECASE,
)
_ROMAN_SECTION_LINE_RE = re.compile(
    r"^(?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+[^:\n]{1,80}:"
)
_ROMAN_SECTION_TITLE_RE = re.compile(
    r"^(\*{0,2})((?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+[^:\n]+:)(\*{0,2})\s*(.*)$",
    re.DOTALL,
)
_ROMAN_SECTION_SPLIT_RE = re.compile(
    r"(?<=[.!?])(?=\s*(?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+[^:\n]{1,80}:)",
)
_ROMAN_TOKEN_RE = re.compile(
    r"\b(VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+[^:\n]{1,80}:"
)


def collapse_italic_quote_marker_spaces(text: str) -> str:
    """Google italik tırnak: ``* \"alıntı\"`` → ``*\"alıntı\"``."""
    return re.sub(r'\*[ \t]+(")', r'*\1', text or "")


def repair_inline_glued_bold(text: str) -> str:
    """Kelimeye yapışık ``olarak** vurgu**`` → ``olarak **vurgu**``."""
    src = re.sub(r"(→)\s*\*\*\s*", r"\1 **", text or "")
    return re.sub(
        r"(?<=[a-zçğıöşüâîû])[ \t]*\*\*[ \t]+([^*\n]+?)\*\*",
        lambda m: f" **{m.group(1).strip()}**",
        src,
        flags=re.IGNORECASE,
    )


def split_glued_secenek_headers(text: str) -> str:
    """Google/Telegram: yapışık **… (A seçeneği):** başlıklarını ayır ve sıkılaştır."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not re.search(r"\([A-E]\s+seçeneği\)", src, re.I):
        return src.strip()
    src = re.sub(r"([.!?])\*\*\s+", r"\1\n\n**", src)
    src = _SECENEK_HEADER_LOOSE_RE.sub(r"**\1**", src)
    src = repair_inline_glued_bold(src)
    src = re.sub(
        r"(\*\*Diğer Seçenekler[^\n*]+\*\*)\s*-\s*\*\*",
        r"\1\n\n- **",
        src,
        flags=re.IGNORECASE,
    )
    return tighten_markdown_markers(src).strip()


def structure_seceneki_solution_outline(text: str) -> str:
    """**(Ad) (A seçeneği):** kalın başlıklı Google çözüm → madde listesi."""
    src = split_glued_secenek_headers(text)
    headers = list(_SECENEK_HEADER_INLINE_RE.finditer(src))
    if len(headers) < 2:
        return src
    out: list[str] = []
    for i, match in enumerate(headers):
        title = match.group(1).strip()
        body_start = match.end()
        body_end = headers[i + 1].start() if i + 1 < len(headers) else len(src)
        body = src[body_start:body_end].strip()
        out.append(f"- **{title}**")
        if body:
            out.append(f"  - {body}")
        out.append("")
    return tighten_markdown_markers("\n".join(out).strip())


def _split_google_verbal_solution(src: str) -> str:
    """Google sözel çözüm: italik tırnak, 'Diğer Seçenekler', A)…E) yapışması.

    ``**…**`` koruması A) harflerini yutmasın diye markdown protect'ten önce.
    """
    src = split_glued_secenek_headers(src)
    src = _ITALIC_QUOTE_TRAIL_RE.sub(r"*\1* ", src)
    src = _ITALIC_QUOTE_LEAD_RE.sub(r" *\1*", src)
    src = collapse_italic_quote_marker_spaces(src)
    src = re.sub(
        r"(\*\*Diğer Seçenekler[^\n*]+\*\*)\s*-\s*\*\*",
        r"\1\n\n- **",
        src,
        flags=re.IGNORECASE,
    )
    src = _DIGER_SECENEKLER_GLUE_RE.sub(r"\n\n**\1**\n", src)
    src = _GLUED_BOLD_LETTER_RE.sub(r"\n**\1)** ", src)
    src = _LINE_BOLD_LETTER_RE.sub(r"**\1)** ", src)
    src = _GLUED_OPTION_LETTER_RE.sub("\n", src)
    src = _OPTION_TITLE_BODY_GLUE_RE.sub(r"\1\n", src)
    return src


def _split_glued_roman_sections(src: str) -> str:
    """Yapışık Romen öncül/madde satırlarını ayır; düz metin (II. Mahmut, II. Kök Türk) korunur."""
    if not src:
        return src
    out = src
    colon_romans = _ROMAN_TOKEN_RE.findall(out)
    if len(set(colon_romans)) >= 2:
        out = re.sub(
            r"(?<!\n)(?<!\*\*)(?=\b(?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+[^:\n]{1,80}:)",
            "\n",
            out,
        )
    math_romans = re.findall(
        r"\b(VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+(?:§§M\d+§§|\$|\\[\(\[])",
        out,
    )
    if len(set(math_romans)) >= 2:
        out = re.sub(
            r"(?<=\$)(?!\n)(?=\s*(?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s)",
            "\n",
            out,
        )
        out = re.sub(
            r"(§§M\d+§§)(?!\n)(?=\s*(?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s)",
            r"\1\n",
            out,
        )
    return out


def normalize_roman_solution_sections(text: str) -> str:
    """Roma rakamlı çözüm maddelerini satır + kalın başlığa dönüştür."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not src:
        return src
    if not _ROMAN_TOKEN_RE.search(src):
        return src

    inner = src
    if inner.startswith("**") and inner.endswith("**") and inner.count("**") == 2:
        inner = inner[2:-2].strip()

    inner = _split_glued_roman_sections(inner)
    parts = [
        part.strip()
        for part in _ROMAN_SECTION_SPLIT_RE.split(inner)
        if part.strip()
    ]
    if len(parts) < 2:
        parts = [line.strip() for line in inner.split("\n") if line.strip()]
    if len(parts) < 2:
        return src

    out: list[str] = []
    matched = 0
    for part in parts:
        title = _ROMAN_SECTION_TITLE_RE.match(part)
        if not title:
            out.append(part)
            continue
        matched += 1
        header = _strip_outer_bold(title.group(2).strip())
        body = (title.group(4) or "").strip()
        out.append(f"**{header}**")
        if body:
            out.append(body)
        out.append("")

    if matched < 2:
        return src
    return "\n".join(out).strip()


def restore_collapsed_breaks(text: str) -> str:
    """Google / sohbet kopyasında yutulan satır kırıklarını geri aç."""
    src = merge_split_inline_dollar_math((text or "").replace("\r\n", "\n").replace("\r", "\n"))
    if not src:
        return src
    math_holders: list[str] = []
    src = _protect_math_spans(src, math_holders)
    src = _split_google_verbal_solution(src)
    md_holders: list[str] = []
    src = _protect_markdown_spans(src, md_holders)
    src = re.sub(
        r"\b(I|II|III|IV|V|VI|VII|VIII|IX|X)\.(?=[A-ZÇĞİÖŞÜÂÎÛ])",
        r"\1. ",
        src,
    )
    # Google günlük çözüm yapıştırması: 10.06.2024, Sonu:, Ayrımı:
    src = re.sub(
        r"(Çözüm Adımları)(?!\n)(?=\d{1,2}\.\d{1,2}\.\d{4})",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(?<=[a-zçğıöşüâîû])(?=\d{1,2}\.\d{1,2}\.\d{4})",
        "\n",
        src,
    )
    src = re.sub(
        r"([.!?])(?!\n)(?=\d{1,2}\.\d{1,2}\.\d{4})",
        r"\1\n",
        src,
    )
    date_holders: list[str] = []

    def _protect_calendar_date(match: re.Match[str]) -> str:
        date_holders.append(match.group(1))
        return f"§§D{len(date_holders) - 1}§§"

    src = re.sub(
        r"(?<!\d)(\d{1,2}\.\d{1,2}\.\d{4})(?!\d)",
        _protect_calendar_date,
        src,
    )
    src = re.sub(
        r"(Sonu:|Ayrımı:|Sonuç:|Başlangıcı ve Ayrımı:|Değerinin Bulunması:)(?!\n)(?=\S)",
        r"\1\n",
        src,
        flags=re.I,
    )
    # Cümle sonu → büyük harf / numaralı madde
    src = re.sub(r"([.!?])(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])", r"\1\n", src)
    src = re.sub(r":(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])", ":\n", src)
    # Düz metindeki tek boşluklu kısa başlık/gövde birleşmesi.
    src = re.sub(
        r"(?m)^([A-ZÇĞİÖŞÜÂÎÛ][^.!?:\n]{2,79}:)[ \t]+(?=[A-ZÇĞİÖŞÜÂÎÛ])",
        r"\1\n",
        src,
    )
    src = re.sub(r"([.!?])(?!\n)(?=\d+\.\s)", r"\1\n", src)
    src = re.sub(r":(?!\n)(?=\d+\.\s)", ":\n", src)
    # Noktalı virgül sonrası yeni cümle / matematik (korumalı veya ham)
    src = re.sub(r";(?!\n)(?=§§M|[\$A-ZÇĞİÖŞÜÂÎÛ])", ";\n", src)
    # Google mantık çözümü: A Seçeneği: / B Seçeneği: (yapışık paragraf)
    src = re.sub(
        r"(?<!\n)(?=[A-E]\s+Seçeneği\s*:)",
        "\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(Adım Adım Çözüm:)(?!\n)(?=\S)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(şunlardır:)(?!\n)(?=Rakamlar)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(r"(§§M\d+§§\))(?!\n)(?=[A-ZÇĞİÖŞÜ])", r"\1\n", src)
    src = re.sub(r"(§§M\d+§§)(?=§§M\d+§§)", r"\1\n", src)
    src = re.sub(r"(§§M\d+§§)(?!\n)(?=[A-ZÇĞİÖŞÜ])", r"\1\n", src)
    src = re.sub(r"(?<=[a-zçğıöşüâîû])(?=§§M)", "\n", src)
    src = re.sub(
        r"(§§M\d+§§)(?!\n)(?=(?:Rakamlar|Kendisi|Son maddede|Elde edilen|Kağıda|Şimdi |Bulduğumuz|Görüldüğü|Now:|Çarpım ))",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(?<!\n)(?=\d+\.\s+(?:Tek/|Kağıttaki))",
        "\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(?<!\n)(?=[A-E]\)\s+(?:\d|[\'\u2019]|[A-Za-zÇĞİÖŞÜçğıöşü]))",
        "\n",
        src,
    )
    src = re.sub(r"([❌✅])(?!\n)(?=[A-E]\))", r"\1\n", src)
    src = re.sub(
        r"(olsaydı:)(?!\n)(?=[\$\\\(])",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(?<!\n)(?=(?:Kendisi|Rakamlar(?:ı|ları|ın)\s+(?:toplamı|çarpımı|farkı|oranı))\s*:)",
        "\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(\((?:Çift|Tek)\))(?!\n)(?=Rakamlar)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(\(Tek\))(?!\n)(?=Görüldüğü)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(\d+\.\s+[^:]+:)(\s*)(?=\\\(|\$|§§M)",
        r"\1\n",
        src,
    )
    src = re.sub(r"([a-zçğıöşüâîû]:)(?!\n)(?=\$)", r"\1\n", src, flags=re.I)
    # Matematik korumalı; kalan çıplak ``$A)`` şık yapışması
    src = re.sub(r"(\$)(?=[A-E]\))", r"\1\n", src)
    # Cümle sonu + rakam (şeklindedir.2 - 3 …)
    src = re.sub(r"([.!?])(?!\n)(?=\d+\s)", r"\1\n", src)
    # camelCase birleşmeleri: GösterimKitabın, sayfaİlk (birim/kısaltma değil)
    src = _COLLAPSED_WORD_BOUNDARY_RE.sub("\n", src)
    src = _restore_collapsed_presence_table(src)
    src = re.sub(r"(?<!\n)(\d+\.\s+Adım)", r"\n\1", src)
    src = re.sub(
        r"(göre\*{0,2})(?!\n)(?=\s+(?:I|II|III|IV|V)\.)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = _split_glued_roman_sections(src)
    src = _restore_markdown_spans(src, md_holders)
    src = re.sub(
        r"§§M(\d+)§§\s*(?=\*\*(?:\d+\.\s+Adım|[a-zçğıöşüâîû]))",
        r"§§M\1§§\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"§§M(\d+)§§\s+(?=(?:ifadelerinden|hangileri|yukarıdakilerden))",
        r"§§M\1§§\n",
        src,
        flags=re.I,
    )
    # Matematik sonrası numaralı adım: $…$3. Gün
    src = re.sub(r"(§§M\d+§§)(?=\d+\.\s)", r"\1\n", src)
    src = re.sub(r"([.!?])(?!\n)(?=§§M\d+§§)", r"\1\n", src)
    src = re.sub(
        r"(§§M\d+§§)(?!\n)(?=(?:Değerinin Bulunması|Sonuç)\s*:)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"§§D(\d+)§§",
        lambda m: date_holders[int(m.group(1))]
        if int(m.group(1)) < len(date_holders)
        else m.group(0),
        src,
    )
    src = _MATH_HOLDER_RE.sub(
        lambda m: math_holders[int(m.group(1))]
        if int(m.group(1)) < len(math_holders)
        else m.group(0),
        src,
    )
    src = re.sub(r"\n{3,}", "\n\n", src)
    src = repair_inline_glued_bold(src)
    src = split_glued_secenek_headers(src)
    return src.lstrip("\n")


_PRESENCE_CELL_RE = re.compile(r"^(Yok|Var)\s*\(\s*[01]\s*\)$", re.IGNORECASE)
_ALLCAPS_NAME_RE = re.compile(r"^[A-ZÇĞİÖŞÜÂÎÛ]{3,}$")
_BIN_CODE_RE = re.compile(r"^[01]{3}$")


def _restore_collapsed_presence_table(text: str) -> str:
    """Google mantık tablosu: ÖğrenciH Harfi…AYNURYok (0)…000GÖZDE…"""
    src = text
    # HarfiE yapışıkken \b çalışmaz; önce başlıkları ayır.
    src = re.sub(
        r"(Öğrenci)(?=[A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)",
        r"\1\n",
        src,
        flags=re.I,
    )
    src = re.sub(
        r"(Harfi)(?=[A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)",
        r"\1\n",
        src,
    )
    src = re.sub(r"(Harfi)(?=Oluşan\s+Benzersiz)", r"\1\n", src)
    src = re.sub(r"(?<!\n)(?=Oluşan Benzersiz)", "\n", src)
    src = re.sub(r"(\))(?=[A-ZÇĞİÖŞÜÂÎÛ]{3,})", r")\n", src)
    src = re.sub(
        r"(?<=[A-ZÇĞİÖŞÜÂÎÛ]{3})(?=(?:Yok|Var)\s*\(\s*[01]\s*\))",
        "\n",
        src,
    )
    src = re.sub(
        r"(\(\s*[01]\s*\))(?=(?:Yok|Var)\s*\()",
        r"\1\n",
        src,
    )
    src = re.sub(r"(\(\s*[01]\s*\))(?=[01]{3}(?:[A-ZÇĞİÖŞÜÂÎÛ]|$))", r"\1\n", src)
    src = re.sub(r"([01]{3})(?=[A-ZÇĞİÖŞÜÂÎÛ])", r"\1\n", src)
    # ZEHRASeçeneklerde — BÜYÜK AD + Title Case
    src = re.sub(
        r"(?<=[A-ZÇĞİÖŞÜÂÎÛ]{3})(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû]{3,})",
        "\n",
        src,
    )
    return src


def _format_presence_table(text: str) -> str:
    """Ayıklanmış Var/Yok satırlarını madde listesine çevir."""
    lines = (text or "").split("\n")
    start = None
    for i, line in enumerate(lines):
        s = line.strip()
        if s == "Öğrenci" or re.search(r"\bHarfi\b", s) or "Benzersiz Kod" in s:
            start = i
            break
    if start is None:
        return text

    headers: list[str] = []
    i = start
    while i < len(lines):
        s = lines[i].strip()
        if not s:
            i += 1
            continue
        if _ALLCAPS_NAME_RE.match(s) or _PRESENCE_CELL_RE.match(s):
            break
        glued_header = re.match(
            r"^(Öğrenci)\s*([A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)$",
            s,
            flags=re.I,
        )
        if glued_header:
            headers.extend((glued_header.group(1), glued_header.group(2)))
            i += 1
            continue
        headers.append(s)
        i += 1
    letter_headers = [
        re.sub(r"\s*Harfi\s*$", "", h, flags=re.I).strip()
        for h in headers
        if h.lower() != "öğrenci" and "kod" not in h.lower()
    ]
    rows: list[tuple[str, list[str], str]] = []
    while i < len(lines):
        s = lines[i].strip()
        if not s:
            i += 1
            continue
        if not _ALLCAPS_NAME_RE.match(s):
            break
        name = s
        i += 1
        cells: list[str] = []
        code = ""
        while i < len(lines):
            t = lines[i].strip()
            if _PRESENCE_CELL_RE.match(t):
                cells.append(t)
                i += 1
            elif _BIN_CODE_RE.match(t):
                code = t
                i += 1
                break
            else:
                break
        if not cells:
            break
        rows.append((name, cells, code))
    if len(rows) < 2:
        return text

    block: list[str] = ["**Harf kodu:**"]
    for name, cells, code in rows:
        bits: list[str] = []
        for idx, cell in enumerate(cells):
            label = letter_headers[idx] if idx < len(letter_headers) else chr(72 + idx)
            kind = "var" if cell.lower().startswith("var") else "yok"
            bits.append(f"{label} {kind}")
        tail = f" → **{code}**" if code else ""
        block.append(f"- **{name}:** {', '.join(bits)}{tail}")

    before = "\n".join(lines[:start]).rstrip()
    after = "\n".join(lines[i:]).lstrip()
    parts = [p for p in (before, "\n".join(block), after) if p]
    return "\n\n".join(parts)


_OPTION_HEADER_RE = re.compile(
    r"^(?:[-•*◦○–—]\s+)?(?:\*\*)?"
    r"([A-E])\)\s+"
    r"([A-ZÇĞİÖŞÜÂÎÛİ][A-ZÇĞİÖŞÜÂÎÛİa-zçğıöşüâîû]*)"
    r"\s*:?(?:\*\*)?\s*$"
)
# Cümle başlıklı şık: A) İnsanlar, … kalmıştır:
_OPTION_TRIAL_HEADER_RE = re.compile(
    r"^(?:[-•*◦○–—]\s+)?(?:\*\*)?"
    r"([A-E])\)\s+"
    r"(.+\S)\s*:?\s*(?:\*\*)?\s*$"
)
_OPTION_TRIAL_TITLE_RE = re.compile(r"[\s',\d]")
_OPTION_BOLD_LETTER_RE = re.compile(
    r"^(?:[-•*◦○–—]\s+)?\*\*\s*([A-E])\s*\)\s*\*\*\s*(.+)$"
)
_OPTION_SECENEGI_INLINE_RE = re.compile(
    r"^(?:[-•*◦○–—]\s+)?(?:\*\*)?"
    r"([A-E])\s+Seçeneği"
    r"\s*:\s*(.*)$",
    re.IGNORECASE,
)
_OPTION_SECENEGI_ONLY_RE = re.compile(
    r"^(?:[-•*◦○–—]\s+)?(?:\*\*)?"
    r"([A-E])\s+Seçeneği"
    r"\s*:?\s*(?:\*\*)?\s*$",
    re.IGNORECASE,
)
_BULLET_LINE_STRIP_RE = re.compile(r"^(\s*)[-•*◦○–—]\s+")
_KURAL_OZETI_RE = re.compile(r"^Kural\s+Özeti\s*:?\s*$", re.IGNORECASE)
_FORMULA_LIST_LABEL_RE = re.compile(
    r"^(Kendisi|Rakamlar(?:ı|ları|ın)\s+(?:toplamı|çarpımı|farkı(?:nın mutlak değeri)?|oranı))\s*:\s*.+",
    re.IGNORECASE,
)
_NUMBERED_SECTION_RE = re.compile(r"^\d+\.\s+.+\S")
_NUMBERED_SECTION_TITLE_RE = re.compile(r"^(\d+\.\s+[^:]+:)(.*)$", re.DOTALL)
_STEP_HEADER_RE = re.compile(r"^\d+\.\s+Adım:", re.IGNORECASE)
_CONDITION_BULLET_RE = re.compile(r"^(?:Rakamlar\s|Son maddede)", re.IGNORECASE)
_ADIM_ADIM_HEADER_RE = re.compile(
    r"^(.*?Adım Adım Çözüm:)\s*(.*)$",
    re.IGNORECASE,
)
_RESULT_TAIL_RE = re.compile(
    r"(→\s*)(🧍\s*)?(Oturuyor|AYAKTA)\.?\s*$",
    re.IGNORECASE,
)
_DESCRIPTIVE_HEADING_RE = re.compile(r"^[A-ZÇĞİÖŞÜÂÎÛ][^.!?:\n]{2,79}:$")


def _emphasize_result_tail(line: str) -> str:
    def repl(match: re.Match[str]) -> str:
        arrow = match.group(1)
        emoji = match.group(2) or ""
        word = match.group(3)
        # Preserve original casing for AYAKTA / Oturuyor
        return f"{arrow}{emoji}**{word}**."

    return _RESULT_TAIL_RE.sub(repl, line)


def _strip_outer_bold(text: str) -> str:
    src = text.strip()
    if src.startswith("**") and src.endswith("**") and src.count("**") == 2:
        return src[2:-2].strip()
    return src


def _clean_option_title(text: str) -> str:
    """Şık başlığından sondaki ``:``, ``**`` artıklarını temizle."""
    t = _strip_outer_bold((text or "").strip())
    t = re.sub(r"\*+$", "", t).strip()
    return t.rstrip(":").strip()


def _is_option_header_line(line: str) -> bool:
    s = line.strip()
    if not s:
        return False
    # Tam biçimlenmiş ``- **A) …:**`` — tekrar outline etme (idempotent koruma).
    if re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+:\*\*\s*$", s) or re.match(
        r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+\*\*\s*$", s
    ):
        return False
    if re.match(r"^\*\*[A-E]\)\s+.+", s):
        return True
    if (
        _OPTION_HEADER_RE.match(s)
        or _OPTION_SECENEGI_ONLY_RE.match(s)
        or _OPTION_SECENEGI_INLINE_RE.match(s)
        or _OPTION_BOLD_LETTER_RE.match(s)
    ):
        return True
    trial = _OPTION_TRIAL_HEADER_RE.match(s)
    if trial and _OPTION_TRIAL_TITLE_RE.search(trial.group(2) or ""):
        title = (trial.group(2) or "").strip()
        if len(title) <= 80:
            return True
    return False


def _parse_option_header(line: str) -> tuple[str, str, str | None]:
    """Harf, kalın başlık (sondaki : hariç), aynı satırdaki gövde."""
    s = line.strip()
    bare = re.match(r"^\*\*([A-E])\)\s+(.+\S)\s*$", s)
    if bare:
        letter = bare.group(1).upper()
        title = _strip_outer_bold(bare.group(2).strip()).rstrip(":").strip()
        return letter, f"{letter}) {title}", None
    m = _OPTION_HEADER_RE.match(s)
    if m:
        letter = m.group(1).upper()
        return letter, f"{letter}) {m.group(2)}", None
    m = _OPTION_SECENEGI_INLINE_RE.match(s)
    if m:
        letter = m.group(1).upper()
        body = (m.group(2) or "").strip()
        return letter, f"{letter} Seçeneği", body or None
    m = _OPTION_SECENEGI_ONLY_RE.match(s)
    if m:
        letter = m.group(1).upper()
        return letter, f"{letter} Seçeneği", None
    m = _OPTION_BOLD_LETTER_RE.match(s)
    if m:
        letter = m.group(1).upper()
        body = (m.group(2) or "").strip()
        return letter, f"{letter})", body or None
    m = _OPTION_TRIAL_HEADER_RE.match(s)
    if m and _OPTION_TRIAL_TITLE_RE.search(m.group(2) or ""):
        letter = m.group(1).upper()
        title = _strip_outer_bold(m.group(2).strip()).rstrip(":").strip()
        return letter, f"{letter}) {title}", None
    raise ValueError(f"not an option header: {line!r}")


def structure_solution_outline(text: str) -> str:
    """Google çözüm yapısını geri kur: madde + A–E iç içe liste (idempotent)."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not src:
        return src
    if re.search(r"(?m)^-\s+\*\*\d+\.\s+Adım:", src, re.I):
        return src
    src = convert_atx_headings_to_bold(src)
    src = re.sub(
        r"(\*\*Diğer Seçenekler[^\n*]+\*\*)\s*-\s*\*\*",
        r"\1\n\n- **",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(r"(→)\*\*\s+", r"\1 **", src)
    if re.search(r"\([A-E]\s+seçeneği\)", src, re.I):
        seceneki = structure_seceneki_solution_outline(src)
        if len(re.findall(r"(?m)^- \*\*", seceneki)) >= 2:
            return seceneki
    src = _format_presence_table(src)
    lines = src.split("\n")
    option_idxs: list[int] = []
    for i, line in enumerate(lines):
        s = line.strip()
        if _is_option_header_line(s):
            option_idxs.append(i)
        elif re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+:\*\*\s*$", s) or re.match(
            r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+\*\*\s*$", s
        ):
            option_idxs.append(i)
    if len(option_idxs) < 2:
        preamble = _structure_preamble_lines(lines)
        return "\n".join(preamble).strip() if preamble else src

    out: list[str] = []
    preamble = lines[: option_idxs[0]]
    out.extend(_structure_preamble_lines(preamble))
    if out and out[-1] != "":
        out.append("")

    for oi, start in enumerate(option_idxs):
        end = option_idxs[oi + 1] if oi + 1 < len(option_idxs) else len(lines)
        block = [ln for ln in lines[start:end] if ln.strip()]
        if not block:
            continue
        head = block[0].strip()
        # Tek satır ``- **A) Title:** body``
        if re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+:\*\*\s+\S", head):
            out.append(head)
            for child in block[1:]:
                out.append(child)
            out.append("")
            continue
        if re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+:\*\*\s*$", head) or re.match(
            r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+\*\*\s*$", head
        ):
            bodies: list[str] = []
            for child in block[1:]:
                raw = child.strip()
                raw = _BULLET_LINE_STRIP_RE.sub("", raw).strip()
                raw = _strip_orphan_trailing_bold(_strip_outer_bold(raw))
                if raw:
                    bodies.append(_emphasize_result_tail(raw))
            if len(bodies) == 1:
                out.append(f"{head} {bodies[0]}")
            elif not bodies:
                out.append(head)
            else:
                out.append(head)
                for body in bodies:
                    out.append(f"  - {body}")
            out.append("")
            continue
        try:
            _letter, title, inline = _parse_option_header(head)
        except ValueError:
            continue
        bodies = []
        if inline:
            body = _strip_orphan_trailing_bold(_strip_outer_bold(inline))
            if body:
                bodies.append(_emphasize_result_tail(body))
        for child in block[1:]:
            raw = child.strip()
            raw = _BULLET_LINE_STRIP_RE.sub("", raw).strip()
            raw = _strip_orphan_trailing_bold(_strip_outer_bold(raw))
            if not raw:
                continue
            bodies.append(_emphasize_result_tail(raw))
        title_clean = _clean_option_title(title)
        if len(bodies) == 1:
            out.append(f"- **{title_clean}:** {bodies[0]}")
        elif not bodies:
            out.append(f"- **{title_clean}:**")
        else:
            out.append(f"- **{title_clean}:**")
            for body in bodies:
                out.append(f"  - {body}")
        out.append("")

    return "\n".join(out).strip()


def _structure_preamble_lines(lines: list[str]) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        if i == 0 and "Adım Adım" in line:
            hdr = _ADIM_ADIM_HEADER_RE.match(line)
            if hdr:
                out.append(f"**{hdr.group(1).strip()}**")
                out.append("")
                rest = hdr.group(2).strip()
                if rest:
                    out.append(rest)
                i += 1
                continue
            stripped = collapse_nested_marks(line.strip())
            if re.match(r"^\*{2,}", stripped):
                out.append(stripped)
            else:
                out.append(f"**{_strip_outer_bold(stripped)}**")
            out.append("")
            i += 1
            continue
        if i == 0 and (
            line.startswith("💡") or "Adim Adim" in line
        ):
            out.append(f"**{_strip_outer_bold(line)}**")
            out.append("")
            i += 1
            continue
        if _FORMULA_LIST_LABEL_RE.match(line):
            while i < len(lines) and _FORMULA_LIST_LABEL_RE.match(lines[i].strip()):
                out.append(f"- {lines[i].strip()}")
                i += 1
            out.append("")
            continue
        if (
            _DESCRIPTIVE_HEADING_RE.match(line)
            and len(line.split()) <= 8
            and not _KURAL_OZETI_RE.match(line)
            and not _DIGER_SECENEKLER_LINE_RE.match(line)
            and not re.search(r"(?:elim|alım|şunlardır):$", line, re.IGNORECASE)
        ):
            body = ""
            if i + 1 < len(lines):
                candidate = lines[i + 1].strip()
                if (
                    candidate
                    and not _DESCRIPTIVE_HEADING_RE.match(candidate)
                    and not _is_option_header_line(candidate)
                    and not _DIGER_SECENEKLER_LINE_RE.match(candidate)
                    and not _FORMULA_LIST_LABEL_RE.match(candidate)
                    and not _CONDITION_BULLET_RE.match(candidate)
                    and not _STEP_HEADER_RE.match(candidate)
                    and not _ROMAN_SECTION_LINE_RE.match(candidate)
                    and not _NUMBERED_SECTION_RE.match(candidate)
                ):
                    body = candidate
                    i += 1
            suffix = f" {body}" if body else ""
            out.append(f"- **{_strip_outer_bold(line)}**{suffix}")
            out.append("")
            i += 1
            continue
        if _CONDITION_BULLET_RE.match(line):
            while i < len(lines) and _CONDITION_BULLET_RE.match(lines[i].strip()):
                out.append(f"- {lines[i].strip()}")
                i += 1
            out.append("")
            continue
        if _STEP_HEADER_RE.match(line):
            core = line.strip()
            if core.startswith("**") and core.endswith("**"):
                out.append(core)
            else:
                out.append(f"**{core}**")
            out.append("")
            i += 1
            continue
        if _ROMAN_SECTION_LINE_RE.match(line):
            title = _ROMAN_SECTION_TITLE_RE.match(line)
            if title and title.group(2).strip():
                header = _strip_outer_bold(title.group(2).strip())
                body = (title.group(4) or "").strip()
                out.append(f"**{header}**")
                if body:
                    out.append(body)
            else:
                out.append(f"**{_strip_outer_bold(line)}**")
            out.append("")
            i += 1
            continue
        if _NUMBERED_SECTION_RE.match(line):
            title = _NUMBERED_SECTION_TITLE_RE.match(line)
            if title and title.group(2).strip():
                out.append(f"**{title.group(1).strip()}**")
                out.append("")
                out.append(title.group(2).strip())
            else:
                out.append(f"**{line}**")
            out.append("")
            i += 1
            continue
        diger = _DIGER_SECENEKLER_LINE_RE.match(line)
        if diger:
            out.append(f"**{diger.group(1).strip()}**")
            out.append("")
            i += 1
            continue
        if _KURAL_OZETI_RE.match(line) or line.lower().startswith("kural özeti"):
            out.append("**Kural Özeti:**")
            i += 1
            while i < len(lines):
                nxt = lines[i].strip()
                if not nxt:
                    i += 1
                    break
                if (
                    nxt.startswith("Şimdi ")
                    or nxt.startswith("Bir öğrenci")
                    or _is_option_header_line(nxt)
                ):
                    break
                body = _BULLET_LINE_STRIP_RE.sub("", nxt).strip()
                body = _strip_outer_bold(body)
                if body:
                    out.append(f"- {body}")
                i += 1
            out.append("")
            continue
        out.append(line)
        i += 1
    return out


def normalize_paste_text(text: str) -> str:
    """rich-format.js normalizePasteText."""
    return normalize_markup(normalize_exam_arrows(normalize_latex(text)))


def collapse_bullet_prefixes(text: str) -> str:
    src = _BULLET_PREFIX_RE.sub("- ", text)
    src = _EMPTY_BULLET_RE.sub("", src)
    src = _MULTI_NL_RE.sub("\n\n", src)
    return src.strip()


def has_latex(text: str) -> bool:
    return bool(_HAS_LATEX_RE.search(text or ""))


def latex_score(text: str) -> int:
    src = text or ""
    # TgQPHd / XPM dump sahte yüksek skor üretmesin
    if _GOOGLE_XPM_SIGNAL_RE.search(src):
        return 0
    dollars = len(re.findall(r"\$", src))
    commands = len(_LATEX_SCORE_FRAC_RE.findall(src))
    return dollars + commands * 2


def _markdown_looks_rich(text: str) -> bool:
    return bool(re.search(r"(\*\*|__|\{green\}|\{red\}|\{blue\})", text))


def _html_looks_rich(html: str) -> bool:
    return bool(
        re.search(
            r"<(?:strong|b|em|i|u)\b|"
            r"font-weight\s*:\s*(?:bold|bolder|[6-9]00)|"
            r"text-decoration(?:-line)?\s*:[^;\"']*underline|"
            r"data-xpm-latex",
            html,
            re.I,
        )
    )


def _structure_score(text: str) -> int:
    bolds = len(re.findall(r"\*\*", text))
    unders = len(re.findall(r"__", text))
    breaks = text.count("\n")
    bullets = len(re.findall(r"^\s*[-•]", text, re.MULTILINE))
    heads = len(re.findall(r"^## ", text, re.MULTILINE))
    return bolds * 3 + unders * 3 + breaks + bullets * 2 + heads * 4


_MATH_STEP_TITLE_GLUE_RE = re.compile(
    r"\*\*[^*\n]+\*\*\*\*(?:\d+\.\s+Adım:|\d+\.)"
)
_MATH_STEP_HEADER_BODY_GLUE_RE = re.compile(r"\):\*\*-\s")
_MATH_STEP_PAREN_SENTENCE_GLUE_RE = re.compile(r"\)\.\-\s+")
_MATH_STEP_INLINE_SONUC_RE = re.compile(r"\*\*\s*Sonuç\s*\*\*", re.IGNORECASE)
_MATH_STEP_ORPHAN_BOLD_LINE_RE = re.compile(
    r"([a-zçğıöşüâîû]{2,})\*\*[ \t]+([^*\n]+?\*\*)",
    re.IGNORECASE,
)
_MATH_STEP_BROKEN_BOLD_WORD_RE = re.compile(
    r"\*\*([^*\n]+?)[ \t]+\*\*([a-zçğıöşüâîû]+:)",
    re.IGNORECASE,
)


_OPTION_BULLET_LINE_RE = re.compile(r"^\s*[-•*◦○–—]\s+\*\*[A-E]\)")


def _line_has_orphan_bold_glue(line: str) -> bool:
    """``sıralama** y < z < x**`` — dengeli ``**Amanname** veya`` sayılmaz."""
    if _OPTION_BULLET_LINE_RE.match(line):
        return False
    for match in _MATH_STEP_ORPHAN_BOLD_LINE_RE.finditer(line):
        if line[: match.start()].count("**") % 2 == 0:
            return True
    return False


def _repair_orphan_bold_glue_on_line(line: str) -> str:
    if _OPTION_BULLET_LINE_RE.match(line):
        return line

    def repl(match: re.Match[str]) -> str:
        if line[: match.start()].count("**") % 2 == 1:
            return match.group(0)
        return f"{match.group(1)} **{match.group(2)}"

    return _MATH_STEP_ORPHAN_BOLD_LINE_RE.sub(repl, line)


def _has_math_step_solution_glue(text: str) -> bool:
    """Matematik adım çözümü: ****1. Adım, ):**-, ).- , ** Sonuç ** yapışmaları."""
    src = text or ""
    if not src.strip():
        return False
    if _MATH_STEP_TITLE_GLUE_RE.search(src):
        return True
    if _MATH_STEP_HEADER_BODY_GLUE_RE.search(src):
        return True
    if _MATH_STEP_PAREN_SENTENCE_GLUE_RE.search(src):
        return True
    if _MATH_STEP_INLINE_SONUC_RE.search(src):
        return True
    if any(_line_has_orphan_bold_glue(line) for line in src.split("\n")):
        return True
    if _MATH_STEP_BROKEN_BOLD_WORD_RE.search(src):
        return True
    return False


def _repair_math_step_solution_glue(text: str) -> str:
    """Matematik adım çözümü yapışmalarını ayır (Gemini / OCR kayıt kusuru)."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not src or not _has_math_step_solution_glue(src):
        return src

    src = re.sub(
        r"\*\*([^*\n]+?)\*\*\*\*(\d+\.\s+Adım:)",
        r"**\1**\n\n- **\2",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r"\*\*([^*\n]+?)\*\*\*\*(\d+\.)",
        r"**\1**\n\n- **\2",
        src,
    )
    src = _MATH_STEP_HEADER_BODY_GLUE_RE.sub("):**\n\n- ", src)
    src = _MATH_STEP_PAREN_SENTENCE_GLUE_RE.sub(").\n\n", src)
    src = _MATH_STEP_INLINE_SONUC_RE.sub("\n\n**Sonuç**\n\n", src)
    fixed_lines: list[str] = []
    for line in src.split("\n"):
        line = _MATH_STEP_BROKEN_BOLD_WORD_RE.sub(r"**\1** \2", line)
        line = _repair_orphan_bold_glue_on_line(line)
        fixed_lines.append(line)
    src = re.sub(r"\n{3,}", "\n\n", "\n".join(fixed_lines))
    return src.strip()


def is_structured_solution_outline(text: str) -> bool:
    """Daha önce biçimlenmiş çözümü ikinci normalizasyondan koru."""
    src = text or ""
    if _GOOGLE_XPM_SIGNAL_RE.search(src) or _GOOGLE_SPEECH_SIGNAL_RE.search(src):
        return False
    if _has_math_step_solution_glue(src):
        return False
    structured_lines = re.findall(
        r"(?m)^\s*(?:-\s+)?\*\*(?:"
        r"[A-E]\)\s+[^*\n]+:|"
        r"[^*\n]+\([A-E]\s+seçeneği\)\s*:|"
        r"(?:VIII|VII|III|VI|IV|IX|II|V|I|X)\.\s+[^*\n]+:|"
        r"[^*\n]{3,80}:"
        r")\*\*",
        src,
    )
    if len(structured_lines) >= 2:
        return True
    # ``- **A) …`` madde listesi (kolon/başlık biçimi ne olursa olsun)
    outlined_options = re.findall(r"(?m)^\s*-\s+\*\*[A-E]\)", src)
    return len(outlined_options) >= 2


_OPTION_HEADER_ONLY_RE = re.compile(
    r"^(\s*[-•*◦○–—]\s+)\*\*([A-E])\)\s+([^*\n]+?):\*\*\s*$"
)
_BROKEN_OPTION_BULLET_RE = re.compile(
    r"^(\s*[-•*◦○–—]\s+)\*\*([A-E])\):\*\*\s+(.+?)\*\*:\s+(.+?)\.\:\*\*\s*$"
)
_OPTION_NESTED_BODY_RE = re.compile(r"^(\s*[-•*◦○–—]\s+)(.+?)\s*$")
_ORPHAN_TRAILING_BOLD_RE = re.compile(
    r"(?m)^\s*[-•*◦○–—]\s+(?!\*\*)(.*\S)\*\*\s*$"
)


def _strip_orphan_trailing_bold(text: str) -> str:
    """Satır sonundaki eşleşmeyen ``**`` kapanışını temizle."""
    src = (text or "").strip()
    if not src.endswith("**"):
        return src
    # Dengeli ``**…**`` sarımı koru; yalnız yetim kapanışı sil.
    if src.startswith("**") and src.count("**") == 2:
        return src
    if src.count("**") % 2 == 1 or not src.startswith("**"):
        return re.sub(r"\*\*\s*$", "", src).strip()
    return src


def _repair_broken_option_bullet_colons(text: str) -> str:
    """``- **A):** Başlık**: gövde.:**`` → ``- **A) Başlık:** gövde.``"""
    out: list[str] = []
    for line in (text or "").replace("\r\n", "\n").split("\n"):
        match = _BROKEN_OPTION_BULLET_RE.match(line)
        if match:
            prefix, letter, title, body = match.groups()
            out.append(f"{prefix}**{letter}) {title.strip()}:** {body.strip()}.")
            continue
        if re.match(r"^\s*[-•*◦○–—]\s+\*\*[A-E]\)", line):
            line = re.sub(r"\.\:\*\*\s*$", ".", line)
        out.append(line)
    return "\n".join(out)


_CHRONO_INTRO_RE = re.compile(r"Kronolojik\s+s[ıi]ralama", re.IGNORECASE)
_CHRONO_ITEM_LINE_RE = re.compile(
    r"^(?:-\s+)?\*\*(?:(\d+)\.\s+)?(.+?\(\d{1,2}(?:-\d{1,2})?\s+"
    r"[A-Za-zçğıöşüÇĞİÖŞÜ]+\s+\d{4}\))\:\*\*\s*(.*)$",
    re.IGNORECASE,
)


def _structure_chronology_solution(text: str) -> str:
    """Kronoloji çözümü: numaralı madde listesi + girişten sonra boş satır."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not _CHRONO_INTRO_RE.search(src):
        return src

    src = re.sub(
        r"(Kronolojik\s+s[ıi]ralama[^\n]*:)\s*\n(?!\n)",
        r"\1\n\n",
        src,
        count=1,
        flags=re.IGNORECASE,
    )

    lines = src.split("\n")
    out: list[str] = []
    in_chrono = False
    item_num = 0

    for raw in lines:
        stripped = raw.strip()
        if not stripped:
            if out and out[-1] != "":
                out.append("")
            continue

        if _CHRONO_INTRO_RE.search(stripped) and not in_chrono:
            in_chrono = True
            out.append(stripped)
            out.append("")
            continue

        if not in_chrono:
            out.append(raw.rstrip())
            continue

        match = _CHRONO_ITEM_LINE_RE.match(stripped)
        if match:
            item_num += 1
            existing_num, title, body = match.groups()
            num = int(existing_num) if existing_num else item_num
            line = f"- **{num}. {title.strip()}:**"
            if body.strip():
                line = f"{line} {body.strip()}"
            out.append(line)
            continue

        out.append(raw.rstrip())

    if item_num < 2:
        return src
    return re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip()


def _repair_glued_italic_open_quotes(text: str) -> str:
    """``kelime*"alıntı"`` → ``kelime *"alıntı"`` (Google sözel çözüm yapışması)."""
    src = collapse_italic_quote_marker_spaces(text or "")
    return re.sub(r'(?<=[a-zçğıöşüâîû])\*"', r' *"', src, flags=re.IGNORECASE)


def _repair_underline_phrase_analysis(text: str) -> str:
    """Altı çizili söz analizi: ``**-** Metindeki``, kırık tırnak maddesi, iç içe madde."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not re.search(r"Metindeki Bağlamı|Seçenekteki Karşılığı", src, re.I):
        return src

    src = _repair_glued_italic_open_quotes(src)
    src = re.sub(
        r"(?m)^\*\*-\*\*\s+(Metindeki Bağlamı|Seçenekteki Karşılığı):\*\*\s*",
        r"  - **\1:** ",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r'(?m)^(- \*\*"(?:[^"\n]+|\.\.\.)"?)\s*$',
        r"\1**",
        src,
    )
    src = re.sub(
        r'(\*\*"[^"\n]+")\s*(Metindeki Bağlamı:)',
        r"\1\n  - **\2",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r'(\*\*"[^"\n]+")\s*(Seçenekteki Karşılığı:)',
        r"\1\n  - **\2",
        src,
        flags=re.IGNORECASE,
    )

    lines = src.split("\n")
    out: list[str] = []
    in_phrase_block = False

    for raw in lines:
        stripped = raw.strip()
        if not stripped:
            if out and out[-1] != "":
                out.append("")
            continue

        if stripped.startswith("📌"):
            out.append(stripped)
            out.append("")
            in_phrase_block = False
            continue

        if re.match(r'^- \*\*".+"\*\*\s*$', stripped):
            in_phrase_block = True
            out.append(stripped)
            continue

        if stripped.startswith('- **"') and not stripped.endswith("**"):
            in_phrase_block = True
            out.append(stripped if stripped.endswith("**") else f"{stripped}**")
            continue

        if re.match(
            r"^\s{2,}-\s+\*\*(Metindeki Bağlamı|Seçenekteki Karşılığı):",
            raw,
            re.I,
        ):
            in_phrase_block = True
            out.append(raw.rstrip())
            continue

        ctx_top = re.match(
            r"^- \*\*(Metindeki Bağlamı|Seçenekteki Karşılığı):\*\*\s",
            stripped,
            re.I,
        )
        if ctx_top and in_phrase_block:
            out.append(f"  {stripped}")
            continue

        in_phrase_block = False
        out.append(stripped)

    src = re.sub(r"\n{3,}", "\n\n", "\n".join(out))
    return src.strip()


def _solution_has_hard_paste_debris(text: str) -> bool:
    """Yapıştırma enkazı (MSO / token-expansion / Docs / glue / XPM / hphantom).

    Soft ``repair != src`` (bilinçli madde işareti kaldırma vb.) buraya girmez —
    üç gate bu sinyalde anlaşır; soft delta yalnız ``solution_has_storage_defects``.
    """
    src = text or ""
    if not src.strip():
        return False
    if looks_like_glued_duplicate_math(src):
        return True
    if looks_like_math_token_expansion_debris(src):
        return True
    if looks_like_docs_annotation_token_debris(src):
        return True
    if looks_like_word_mso_paste_debris(src):
        return True
    if _GOOGLE_XPM_SIGNAL_RE.search(src):
        return True
    if _GOOGLE_SPEECH_SIGNAL_RE.search(src):
        return True
    if looks_like_xpm_html_attribute_debris(src):
        return True
    if "hphantom" in src or "\\phantom" in src:
        return True
    return False


def _solution_needs_pipeline_repair(text: str) -> bool:
    """Ham sinyal — yapıştırma/outline pipeline'ı atlanmamalı mı?

    Hard paste debris ile ``solution_has_storage_defects`` aynı enkaz kümesini
    paylaşır; soft repair-delta bilinçli biçimi bozmamak için burada yok.
    """
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src.strip():
        return False
    # Tek kaynak: hard paste debris (MSO / token-expansion / Docs / XPM …)
    if _solution_has_hard_paste_debris(src):
        return True
    if _looks_like_fragmented_math_debris(src):
        return True
    # XPM sonrası glue: math+prose / kırık bold / emoji sonuç
    if _has_capital_glued_after_inline_math(src):
        return True
    if re.search(r"\$[^$\n]+\$\*\*\d+\.", src):
        return True
    # ``yaşındadır- Büyük`` (küçük harf + tire + büyük); Teklif-i / satırsonu Analizi-\n**A değil
    if re.search(r"[a-zçğıöşüâîû]\)?-[ \t]*(?:\*\*)?[A-ZÇĞİÖŞÜ]", src):
        return True
    if re.search(r"\}\$\s*[👶📌🚨]", src):
        return True
    if re.search(r"(?m)^[ \t]*#{1,3}[ \t]+\S", src):
        return True
    if re.search(r"\*\*metin\*\*\s*$", src, re.IGNORECASE):
        return True
    if re.search(r"(?m)^\s*-\s*\*\*\s*$", src):
        return True
    if _ORPHAN_TRAILING_BOLD_RE.search(src):
        return True
    if re.search(r"(?m)^\s*[-•*◦○–—]\s+\*\*[A-E]\):\*\*", src):
        return True
    lines = src.split("\n")
    for i, line in enumerate(lines[:-1]):
        if not _OPTION_HEADER_ONLY_RE.match(line):
            continue
        nxt = lines[i + 1]
        body_m = _OPTION_NESTED_BODY_RE.match(nxt)
        if not body_m:
            continue
        body = body_m.group(2).strip()
        if re.match(r"^(?:\*\*)?[A-E]\)", body):
            continue
        extra_child = False
        if i + 2 < len(lines):
            mid = lines[i + 2]
            mid_s = mid.strip()
            if (
                mid_s
                and _OPTION_NESTED_BODY_RE.match(mid)
                and not _OPTION_HEADER_ONLY_RE.match(mid)
                and not re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)", mid_s)
            ):
                extra_child = True
        if extra_child:
            continue
        return True
    if re.search(r"[.!?]-\s*\*\*", src):
        return True
    if re.search(r"[^\n]:-\s*\*\*", src):
        return True
    if re.search(r"Diğer Seçenekler[^\n]+-\s*\*\*", src, re.IGNORECASE):
        return True
    if re.search(
        r"(?m)^\s*-\s+\*\*[A-E]\)(?:(?!.*:)[^\n])*(?<!\*\*)\s*$",
        src,
    ):
        return True
    if re.search(r"\?-\s*\*\*", src, re.IGNORECASE):
        return True
    if re.search(r"[a-zçğıöşüâîû]\.- \*\*", src, re.IGNORECASE):
        return True
    if re.search(r"-\*\*\s+[A-E]\)", src, re.IGNORECASE):
        return True
    if re.search(r"(?m)^\s*-\s+\*\*\s+[A-E]\)", src):
        return True
    if re.search(r"Diğer Seçenekler", src, re.IGNORECASE):
        option_hits = len(re.findall(r"(?m)^\s*-\s+\*\*[A-E]\)", src))
        glued_options = len(re.findall(r"[A-E]\)\s+[A-ZÇĞİÖŞÜ]", src))
        if glued_options >= 2 and option_hits < 2:
            return True
    if _has_glued_numbered_items(src):
        return True
    if _has_unbulleted_numbered_bold_items(src):
        return True
    if _CHRONO_INTRO_RE.search(src):
        chrono_items = len(_CHRONO_ITEM_LINE_RE.findall(src))
        numbered = len(re.findall(r"(?m)^-\s+\*\*\d+\.\s+", src))
        if chrono_items >= 2 and numbered < chrono_items:
            return True
        if re.search(r"Kronolojik[^\n]*:\n(?!\n)(?:-\s+)?\*\*", src, re.I):
            return True
    if re.search(
        r"(?m)^\*\*-\*\*\s+(Metindeki Bağlamı|Seçenekteki Karşılığı):",
        src,
        re.I,
    ):
        return True
    if re.search(r'(?m)^- \*\*"[^"\n]+\.\.\."\s*$', src):
        return True
    if re.search(r'(?<=[a-zçğıöşüâîû])\*"', src, re.I):
        return True
    for i, line in enumerate(lines):
        if line.startswith(("  ", "\t")):
            continue
        if not re.match(
            r"^- \*\*(Metindeki Bağlamı|Seçenekteki Karşılığı):",
            line.strip(),
            re.I,
        ):
            continue
        if i <= 0:
            continue
        prev = lines[i - 1].strip()
        if prev.startswith('- **"') or re.match(r'^- \*\*".+"\*\*', prev):
            return True
    if _has_math_step_solution_glue(src):
        return True
    return False


def solution_has_storage_defects(text: str) -> bool:
    """Kayıtlı çözüm onarım gerektiriyor mu?"""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not src:
        return False
    # Hard paste debris — pipeline / looks_normalized ile aynı küme
    if _solution_has_hard_paste_debris(src):
        return True
    return repair_solution_storage_defects(src) != src


_ARABIC_NUM_TOKEN_RE = re.compile(r"(?:(?<=\*\*)\s+|(?:^|(?<=\s)))\d+\.\s+")
_GLUED_NUMBERED_SPLIT_RE = re.compile(r"(?<=\*\*)\s+(?=\d+\.\s+)")
_SENTENCE_NUMBERED_SPLIT_RE = re.compile(r"(?<=[.!?])\s+(?=\d+\.\s+)")


def _has_glued_numbered_items(text: str) -> bool:
    """Aynı satırda birden fazla ``1. / 2.`` madde (Gemini yapışması)."""
    for line in (text or "").split("\n"):
        if len(_ARABIC_NUM_TOKEN_RE.findall(line)) >= 2:
            return True
    return False


_FULL_LINE_NUMBERED_BOLD_RE = re.compile(r"^\*\*(\d+\.\s+.+\S)\*\*\s*$")


def _has_unbulleted_numbered_bold_items(text: str) -> bool:
    """Ardışık ``**1. …**`` satırları madde listesine alınmamış (önizleme riski)."""
    run = 0
    for raw in (text or "").split("\n"):
        line = raw.strip()
        if not line:
            continue
        if _FULL_LINE_NUMBERED_BOLD_RE.match(line):
            run += 1
            if run >= 2:
                return True
            continue
        if run:
            run = 0
    return False


def structure_numbered_bold_lines_as_list(text: str) -> str:
    """``**1. …**`` + ``**2. …**`` → ``- **1. …**`` madde listesi."""
    lines = (text or "").replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        match = _FULL_LINE_NUMBERED_BOLD_RE.match(raw.strip())
        if not match:
            out.append(raw)
            i += 1
            continue
        run: list[str] = []
        start = i
        while i < len(lines):
            if not lines[i].strip():
                i += 1
                continue
            m = _FULL_LINE_NUMBERED_BOLD_RE.match(lines[i].strip())
            if not m:
                break
            run.append(m.group(1))
            i += 1
        if len(run) >= 2:
            if out and out[-1].strip():
                out.append("")
            for item in run:
                out.append(f"- **{item}**")
            if i < len(lines) and lines[i].strip():
                out.append("")
        else:
            out.append(lines[start])
            i = start + 1
    return re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip()


def split_glued_numbered_bold_items(text: str) -> str:
    """``**1. …** 2. …** 3. …**`` → ayrı ``**N. …**`` satırları."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src.strip() or not _has_glued_numbered_items(src):
        return src
    out: list[str] = []
    for raw in src.split("\n"):
        line = raw.strip()
        if len(_ARABIC_NUM_TOKEN_RE.findall(line)) < 2:
            out.append(raw)
            continue
        parts = _GLUED_NUMBERED_SPLIT_RE.split(line)
        if len(parts) < 2:
            parts = _SENTENCE_NUMBERED_SPLIT_RE.split(line)
        if len(parts) < 2:
            out.append(raw)
            continue
        if out and out[-1].strip():
            out.append("")
        for part in parts:
            piece = part.strip().strip("*").strip()
            if not piece:
                continue
            if re.match(r"^\d+\.\s+", piece):
                out.append(f"**{piece}**")
                out.append("")
            else:
                out.append(piece)
    return re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip()


def _collapse_option_header_body_lines(text: str) -> str:
    """``- **A) Title:**\n  - body.**`` → ``- **A) Title:** body``."""
    lines = (text or "").replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        header_m = _OPTION_HEADER_ONLY_RE.match(lines[i])
        if header_m and i + 1 < len(lines):
            body_m = _OPTION_NESTED_BODY_RE.match(lines[i + 1])
            if body_m:
                raw_body = body_m.group(2).strip()
                if not re.match(r"^(?:\*\*)?[A-E]\)", raw_body) and not re.match(
                    r"^\*\*[^*\n]+\*\*", raw_body
                ):
                    has_extra_child = False
                    if i + 2 < len(lines):
                        mid = lines[i + 2]
                        mid_s = mid.strip()
                        if (
                            mid_s
                            and _OPTION_NESTED_BODY_RE.match(mid)
                            and not _OPTION_HEADER_ONLY_RE.match(mid)
                            and not re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)", mid_s)
                        ):
                            has_extra_child = True
                    if not has_extra_child:
                        body = _strip_orphan_trailing_bold(raw_body)
                        body = re.sub(r"^\*\*\s*", "", body).strip()
                        letter = header_m.group(2)
                        title = header_m.group(3).strip().rstrip(":").strip()
                        if body:
                            out.append(f"- **{letter}) {title}:** {body}")
                        else:
                            out.append(f"- **{letter}) {title}:**")
                        i += 2
                        continue
        orphan = re.match(
            r"^(\s*[-•*◦○–—]\s+)(?!\*\*[A-E]\))(.+?)\*\*\s*$",
            lines[i],
        )
        if orphan:
            cleaned = _strip_orphan_trailing_bold(orphan.group(2) + "**")
            out.append(f"{orphan.group(1)}{cleaned}")
            i += 1
            continue
        out.append(lines[i])
        i += 1
    return "\n".join(out)


def _repair_broken_option_bold_blocks(text: str) -> str:
    """``**A) Başlık\\nGövde\\n\\n**`` gibi yarım kalın şık bloklarını madde listesine çevir."""
    lines = (text or "").replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        if re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+:\*\*\s+\S", line):
            # Zaten tek satır ``- **A) Title:** body``
            out.append(raw)
            i += 1
            continue
        if re.match(r"^[-•*◦○–—]\s+\*\*[A-E]\)[^*\n]+:\*\*\s*$", line):
            out.append(raw)
            i += 1
            continue
        m = re.match(r"^(?:-\s+)?\*\*([A-E])\)\s+(.+)$", line)
        # Dengeli `**A) Başlık**` — sonraki maddeyle birleştirme
        if m and line.startswith("**") and line.endswith("**") and line.count("**") == 2:
            out.append(raw)
            i += 1
            continue
        if m and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            child = re.match(r"^[-•*◦○–—]\s+(.+)$", nxt)
            if child and (
                re.match(r"^\*\*[A-E]\)", child.group(1).strip())
                or re.match(r"^\*\*[^*\n]+\*\*", child.group(1).strip())
            ):
                child = None
            if (
                nxt
                and nxt != "**"
                and not re.match(r"^\*\*[A-E]\)", nxt)
                and (child or not re.match(r"^[-•*◦○–—]", nxt))
            ):
                letter = m.group(1)
                title = _clean_option_title(m.group(2))
                body = child.group(1).strip() if child else nxt
                body = _strip_orphan_trailing_bold(body)
                out.append(f"- **{letter}) {title}:** {body}" if body else f"- **{letter}) {title}:**")
                out.append("")
                i += 2
                if i < len(lines) and lines[i].strip() == "**":
                    i += 1
                continue
        if line == "**":
            i += 1
            continue
        out.append(raw)
        i += 1
    return "\n".join(out)


def _repair_glued_heading_after_broken_colon(text: str) -> str:
    """``söylenebilir.:** 🚨 Başlık`` — şık satırı değilse satır kır."""
    out: list[str] = []
    for line in (text or "").replace("\r\n", "\n").split("\n"):
        if re.match(r"^\s*[-•*◦○–—]\s+\*\*[A-E]\)", line):
            out.append(line)
            continue
        out.append(
            re.sub(r"([.!?])\:\*\*[ \t]+(?=\S)", r"\1\n\n**", line)
        )
    return "\n".join(out)


def repair_solution_storage_defects(text: str) -> str:
    """Yapışık ipucu/şık satırları ve bozuk madde işaretlerini onar."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not src:
        return src

    src = convert_atx_headings_to_bold(src)
    src = strip_paste_fragment_markers(src)
    src = scrub_docs_annotation_token_debris(src)
    src = scrub_hphantom_math_debris(src)
    src = scrub_math_token_expansion_debris(src)
    src = scrub_glued_duplicate_math(src)
    src = scrub_google_math_speech_debris(src)
    src = _repair_underline_phrase_analysis(src)
    # Yapışık madde: ``…**- **Başlık`` / ``…yayımladı.- **Sonraki madde``
    # Yalnızca aynı satır — ``\s*`` satır sınırını aşmasın (``.:**\\n\\n- **E``)
    src = re.sub(r"(\*\*)[ \t]*-\s*\*\*", r"\1\n\n- **", src)
    src = re.sub(r"([.!?])[ \t]*-\s*\*\*", r"\1\n\n- **", src)
    src = _repair_glued_heading_after_broken_colon(src)
    src = _repair_broken_option_bullet_colons(src)
    src = _repair_math_step_solution_glue(src)
    src = split_glued_numbered_bold_items(src)
    src = structure_numbered_bold_lines_as_list(src)
    src = re.sub(r"\*\*metin\*\*\s*$", "", src, flags=re.IGNORECASE)
    src = re.sub(r"(?m)^\s*-\s*\*\*\s*$", "", src)
    src = re.sub(r"(?m)^\s*\*\*\s*$", "", src)
    src = re.sub(r"(\S)(📌)", r"\1\n\n\2", src)
    src = re.sub(r"([^\n]):-\s*\*\*", r"\1:\n\n**", src)
    src = re.sub(
        r"([a-zçğıöşüâîû])\.-\s*\*\*\s*([A-E])\)",
        r"\1.\n\n- **\2)",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r"(📌\s*)?(Diğer Seçenekler[^\n-]+)-\s*\*\*\s*([A-E])\)\s+([^\n]+)",
        lambda m: (
            f"{m.group(1) or ''}**{m.group(2).strip()}**\n\n"
            f"- **{m.group(3)}) {m.group(4).strip()}**"
        ),
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r"(📌\s*)(Diğer Seçenekler[^\n-]+)(?=\s*-\s*\*\*)",
        r"\1**\2**",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(r"\?-\s*\*\*\s*([A-E])\)", r"?\n\n- **\1)", src, flags=re.IGNORECASE)
    src = re.sub(r"-\*\*\s+([A-E])\)", r"- **\1)", src, flags=re.IGNORECASE)
    src = re.sub(r"(?m)^(\s*-\s*)\*\*\s+([A-E])\)", r"\1**\2)", src)
    src = re.sub(r"([.!?])-\s*\*\*\"", r'\1\n\n**"', src)
    src = re.sub(r"\.-\s*\*\*(?=\s*(?:\n|$))", ".\n\n", src)
    src = re.sub(
        r"\*\*\s*(Diğer Seçenekler(?:in)?[^\n*]+?)\s*\*\*",
        r"**\1**",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r"(📌\s*)(Diğer Seçenekler[^\n?]+\?)",
        r"\1**\2**",
        src,
        flags=re.IGNORECASE,
    )
    src = re.sub(
        r"(\*\*Diğer Seçenekler[^\n*]+\*\*)\s*-?\s*\*\*",
        r"\1\n\n- **",
        src,
        flags=re.IGNORECASE,
    )
    src = _repair_broken_option_bold_blocks(src)
    src = _collapse_option_header_body_lines(src)
    src = _structure_chronology_solution(src)
    if re.search(r"Diğer Seçenekler", src, re.IGNORECASE) or len(
        re.findall(r"(?m)^(?:-\s+)?\*\*[A-E]\)", src)
    ) >= 2:
        src = re.sub(
            r"(?m)^(?:-\s*)?\*\*\s*([A-E])\s*\)\s*\*\*\s+(.+)$",
            r"- **\1):** \2",
            src,
        )
        src = re.sub(r"(?m)^\*\*([A-E])\)\s+", r"- **\1) ", src)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.strip()


def _touchup_storage_solution(text: str) -> str:
    """Kayıtlı çözüm: outline atlama; ok/LaTeX/entity temizliği (idempotent).

    ``repair_solution_storage_defects`` burada çağrılmaz — kusursuz metinde
    bilinçli biçim değişikliklerini (ör. liste işaretini kaldırma) geri yazardı.
    Kusurlu metin ``normalize_pasted_solution`` içinde ayrıca onarılır.
    """
    src = _decode_entities(text or "")
    src = convert_atx_headings_to_bold(src)
    src = normalize_exam_arrows(normalize_latex(repair_vert_groups(src)))
    return src


def looks_storage_normalized_solution(text: str) -> bool:
    """DB'de kayıtlı, pipeline'dan geçmiş çözüm — yapıştırma adımını atla.

    Hard paste debris varken asla True dönmez (MSO + yapılandırılmış outline
    early-exit bug'ı). Soft ``repair != src`` bilinçli biçimi korumak için
    burada early-exit'i engellemez; ``_finalize_storage_solution`` kusur
    döngüsü looks_normalized=False iken çalışır.
    """
    src = (text or "").strip()
    if not src:
        return False
    # hard debris ⇒ ¬looks_normalized (has_defects hard kümesi ile aynı)
    if _solution_has_hard_paste_debris(src):
        return False
    if _solution_needs_pipeline_repair(src):
        return False
    if is_structured_solution_outline(src):
        return True
    if re.search(r"(?m)^\*\*💡?\s*Adım Adım Çözüm\*\*", src, re.I):
        return True
    if re.search(r"(?m)^(?:-\s+)?\*\*\d+\.\s+", src):
        return not _has_unbulleted_numbered_bold_items(src)
    return False


def _align_list_to_plain(from_html: str, from_plain: str) -> str:
    html = collapse_bullet_prefixes(from_html)
    plain_list = len(re.findall(r"^\s*[-•*]\s+", from_plain, re.MULTILINE))
    html_list = len(re.findall(r"^\s*[-•*]\s+", html, re.MULTILINE))
    if html_list > 0 and plain_list == 0:
        return _BULLET_LINE_RE.sub("", html).strip()
    return html


def choose_paste_text(plain: str, html: str = "") -> str:
    """rich-format.js choosePasteText — düz/HTML yapıştırma seçimi."""
    from_plain = collapse_bullet_prefixes(
        collapse_nested_marks(normalize_paste_text(plain or ""))
    )
    from_html = html_clipboard_to_text(html) if (html or "").strip() else ""
    if from_html and from_plain:
        from_html = _align_list_to_plain(from_html, from_plain)
    # Google Docs XPM: HTML latex çıkardıysa plain dump'ı seçme
    if (
        from_html
        and _GOOGLE_XPM_SIGNAL_RE.search(plain or "")
        and not _GOOGLE_XPM_SIGNAL_RE.search(from_html)
    ):
        return collapse_bullet_prefixes(from_html)
    if (
        from_html
        and re.search(r"data-xpm-latex", html or "", re.I)
        and not _GOOGLE_XPM_SIGNAL_RE.search(from_html)
    ):
        return collapse_bullet_prefixes(from_html)
    if not from_html:
        return from_plain
    if not from_plain:
        return collapse_bullet_prefixes(from_html)
    html_rich = _html_looks_rich(html)
    plain_md = _markdown_looks_rich(from_plain)
    html_md = _markdown_looks_rich(from_html)
    if html_rich and html_md and not plain_md:
        return from_html
    if plain_md and not html_md:
        return from_plain
    if html_rich and html_md:
        return from_html
    plain_has = has_latex(from_plain)
    html_has = has_latex(from_html)
    if plain_has and (not html_has or latex_score(from_plain) >= latex_score(from_html)):
        return from_plain
    if _structure_score(from_html) >= _structure_score(from_plain):
        return from_html
    return from_html or from_plain
