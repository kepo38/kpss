"""Panel ve Telegram çözüm metni normalizasyonu — ortak yardımcılar.

Panel (`rich_text_panel`) ve Telegram (`rich_text_telegram`) ayrı giriş
noktalarına sahiptir; bu modül paylaşılan LaTeX/markdown/HTML dönüşümlerini içerir.
"""

from __future__ import annotations

import re

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
    (re.compile(r"\*\*__\*\*([^*]+)\*\*__\*\*"), r"**__\1__**"),
    (re.compile(r"__\*\*__([^_]+)__\*\*__"), r"__**\1**__"),
    (re.compile(r"\*\*\s*\*\*([^*]+)\*\*\s*\*\*"), r"**\1**"),
    (re.compile(r"__\s*__([^_]+)__\s*__"), r"__\1__"),
    (re.compile(r"\*{4,}([^*\n]+)\*{4,}"), r"**\1**"),
    (re.compile(r"_{4,}([^_\n]+)_{4,}"), r"__\1__"),
)

_TIGHTEN_PATTERNS: tuple[tuple[re.Pattern[str], str, str], ...] = (
    (re.compile(r"\*\*[ \t]+(.+?)[ \t]+\*\*", re.DOTALL), "**", "**"),
    (re.compile(r"__[ \t]+(.+?)[ \t]+__", re.DOTALL), "__", "__"),
    (re.compile(r"(?<!\*)\*[ \t]+(.+?)[ \t]+\*(?!\*)", re.DOTALL), "*", "*"),
    (re.compile(r"\*\*(.+?)[ \t]+\*\*", re.DOTALL), "**", "**"),
    (re.compile(r"__(.+?)[ \t]+__", re.DOTALL), "__", "__"),
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

_SPLIT_BOLD_RE = re.compile(r"\*\*([^\n*][^\n]*?)\n\s+([^\n*][^\n]*?)\*\*")

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
        .replace("\x09ext{", r"\text{")
        .replace("\x09imes", r"\times")
        .replace("\x09heta", r"\theta")
        .replace("\x09an", r"\tan")
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


def normalize_latex(text: str) -> str:
    src = merge_split_inline_dollar_math(repair_latex_escapes(text or ""))
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
    return src


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


def normalize_markup(text: str) -> str:
    """math-render.js normalizeMarkup (+ HTML yedek dönüşümü)."""
    src = (
        _decode_entities(text or "")
        .replace("\r\n", "\n")
        .replace("\r", "\n")
    )
    src = _ZWSP_RE.sub("", src)
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

    def stash_display(match: re.Match[str]) -> str:
        display.append(match.group(0))
        return f"§§D{len(display) - 1}§§"

    src = re.sub(r"\$\$[\s\S]+?\$\$", stash_display, src)
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


def restore_collapsed_breaks(text: str) -> str:
    """Google / sohbet kopyasında yutulan satır kırıklarını geri aç."""
    src = merge_split_inline_dollar_math((text or "").replace("\r\n", "\n").replace("\r", "\n"))
    if not src:
        return src
    math_holders: list[str] = []
    src = _protect_math_spans(src, math_holders)
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
    src = re.sub(r"(\$)(?!\n)(?=[A-ZÇĞİÖŞÜ])", r"\1\n", src)
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
    roman_tokens = re.findall(r"\b(I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s", src)
    if len(set(token.rstrip() for token in roman_tokens)) >= 2:
        src = re.sub(
            r"(?<!\n)(?=\b(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s)",
            "\n",
            src,
        )
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


def _is_option_header_line(line: str) -> bool:
    s = line.strip()
    if not s:
        return False
    return bool(
        _OPTION_HEADER_RE.match(s)
        or _OPTION_SECENEGI_ONLY_RE.match(s)
        or _OPTION_SECENEGI_INLINE_RE.match(s)
    )


def _parse_option_header(line: str) -> tuple[str, str, str | None]:
    """Harf, kalın başlık (sondaki : hariç), aynı satırdaki gövde."""
    s = line.strip()
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
    raise ValueError(f"not an option header: {line!r}")


def structure_solution_outline(text: str) -> str:
    """Google çözüm yapısını geri kur: madde + A–E iç içe liste (idempotent)."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not src:
        return src
    src = _format_presence_table(src)
    lines = src.split("\n")
    option_idxs = [
        i for i, line in enumerate(lines) if _is_option_header_line(line.strip())
    ]
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
        try:
            _letter, title, inline = _parse_option_header(block[0].strip())
        except ValueError:
            continue
        out.append(f"- **{title}:**")
        if inline:
            body = _strip_outer_bold(inline)
            if body:
                out.append(f"  - {_emphasize_result_tail(body)}")
        for child in block[1:]:
            raw = child.strip()
            raw = _BULLET_LINE_STRIP_RE.sub("", raw).strip()
            raw = _strip_outer_bold(raw)
            if not raw:
                continue
            out.append(f"  - {_emphasize_result_tail(raw)}")
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
            out.append(f"**{_strip_outer_bold(line)}**")
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
            r"text-decoration(?:-line)?\s*:[^;\"']*underline",
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
    if from_html:
        from_html = _align_list_to_plain(from_html, from_plain)
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
