"""Geometri şekilleri için SVG çıkarımı ve güvenlik süzgeci."""

from __future__ import annotations

import re

_SVG_BLOCK = re.compile(r"<svg[\s\S]*?</svg>", re.IGNORECASE)
_FORBIDDEN = re.compile(
    r"(<\s*script\b|<\s*foreignobject\b|<\s*iframe\b|<\s*embed\b|<\s*object\b|"
    r"javascript:|data:text/html|on\w+\s*=|<!ENTITY\b|<!DOCTYPE\b|<\?xml-stylesheet\b)",
    re.IGNORECASE,
)
_EXTERNAL_HREF = re.compile(
    r"(?:xlink:)?href\s*=\s*['\"]?(?!#)[^'\"\s>]+",
    re.IGNORECASE,
)
_DRAW_TAG = re.compile(
    r"<\s*(path|line|polyline|polygon|circle|rect|ellipse|text|g)\b",
    re.IGNORECASE,
)


def extract_svg(raw: str) -> str:
    """Ham model çıktısından yalnızca SVG bloğunu al."""
    text = (raw or "").strip()
    if not text:
        return ""
    text = text.replace("```svg", "").replace("```xml", "").replace("```", "")
    match = _SVG_BLOCK.search(text)
    if match:
        return match.group(0).strip()
    if text.lower().startswith("<svg"):
        end = text.lower().rfind("</svg>")
        if end >= 0:
            return text[: end + len("</svg>")].strip()
    return ""


def is_safe_svg(code: str) -> bool:
    if not code:
        return False
    lower = code.lower()
    if "<svg" not in lower or "</svg>" not in lower:
        return False
    if _FORBIDDEN.search(code):
        return False
    if _EXTERNAL_HREF.search(code):
        return False
    return bool(_DRAW_TAG.search(code))
