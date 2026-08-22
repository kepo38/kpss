"""Panel rich-format.js + math-render.js ile uyumlu çözüm metni normalizasyonu.

Panelde js-rich textarea yapıştırma kurallarının sunucu tarafı karşılığı.
Telegram çözüm kaydı ve panel solution kaydı aynı pipeline'ı kullanır.
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
    src = (
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


def normalize_latex(text: str) -> str:
    src = repair_latex_escapes(text or "")
    src = re.sub(
        r"\\\[([\s\S]+?)\\\]",
        lambda m: f"$${m.group(1).strip()}$$",
        src,
    )
    src = re.sub(
        r"\\\(([\s\S]+?)\\\)",
        lambda m: f"${m.group(1).strip()}$",
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


def normalize_paste_text(text: str) -> str:
    """rich-format.js normalizePasteText."""
    return normalize_markup(normalize_exam_arrows(normalize_latex(text)))


def _protect_math(text: str, holders: list[str]) -> str:
    def repl(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"§§M{len(holders) - 1}§§"

    return re.sub(r"\$\$[\s\S]+?\$\$|\$[^$\n]+\$", repl, text)


def restore_collapsed_breaks(text: str) -> str:
    """math-render.js restoreCollapsedBreaks — sohbet kopyasında yutulan satır kırıkları."""
    src = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not src:
        return src
    math_holders: list[str] = []
    src = _protect_math(src, math_holders)
    md_holders: list[str] = []
    src = _protect_markdown_spans(src, md_holders)
    src = re.sub(r"([.!?])(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])", r"\1\n", src)
    src = re.sub(r":(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])", ":\n", src)
    src = re.sub(r"([.!?])(?!\n)(?=\d+\.\s)", r"\1\n", src)
    src = re.sub(r":(?!\n)(?=\d+\.\s)", ":\n", src)
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
    src = _MATH_HOLDER_RE.sub(
        lambda m: math_holders[int(m.group(1))]
        if int(m.group(1)) < len(math_holders)
        else m.group(0),
        src,
    )
    src = re.sub(r"(\$)(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])", r"\1\n", src)
    src = re.sub(r"(\$)\s*(?=\*\*[a-zçğıöşüâîû])", r"\1\n", src, flags=re.I)
    src = re.sub(r"\n{3,}", "\n\n", src)
    return src.lstrip("\n")


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


def telegram_entities_to_markdown(text: str, entities: list[dict] | None) -> str:
    """Telegram message.entities → panel markdown."""
    if not text or not entities:
        return text
    marks: list[tuple[int, int, str, str]] = []
    for ent in entities:
        ent_type = str(ent.get("type") or "")
        offset = int(ent.get("offset") or 0)
        length = int(ent.get("length") or 0)
        if length <= 0:
            continue
        start = _utf16_index_to_py(text, offset)
        end = _utf16_index_to_py(text, offset + length)
        if start >= end:
            continue
        if ent_type == "bold":
            marks.append((start, end, "**", "**"))
        elif ent_type == "italic":
            marks.append((start, end, "*", "*"))
        elif ent_type == "underline":
            marks.append((start, end, "__", "__"))
        elif ent_type == "strikethrough":
            marks.append((start, end, "~~", "~~"))
        elif ent_type in {"code", "pre"}:
            marks.append((start, end, "`", "`"))
    if not marks:
        return text
    marks.sort(key=lambda item: (item[0], item[1] - item[0]), reverse=True)
    out = text
    for start, end, open_m, close_m in marks:
        segment = out[start:end]
        if not segment.strip():
            continue
        wrapped = _wrap_markdown_node(
            segment,
            bold=open_m == "**",
            italic=open_m == "*",
            underline=open_m == "__",
        )
        out = out[:start] + wrapped + out[end:]
    return out


def normalize_pasted_solution(
    text: str,
    *,
    entities: list[dict] | None = None,
    html: str = "",
) -> str:
    """Panel js-rich yapıştırma + Telegram metni → kaydedilecek çözüm metni."""
    raw = (text or "").strip()
    html_src = (html or "").strip()
    if not raw and not html_src:
        return ""
    if entities and raw:
        raw = telegram_entities_to_markdown(raw, entities)
    if _HTML_TAG_RE.search(raw):
        chosen = choose_paste_text(raw, raw)
    elif html_src:
        chosen = choose_paste_text(raw, html_src)
    else:
        chosen = choose_paste_text(raw, "")
    chosen = restore_collapsed_breaks(chosen)
    return normalize_turkish_text(chosen).strip()
