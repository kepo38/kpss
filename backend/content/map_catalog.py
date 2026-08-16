"""Static map assets and template metadata for geography questions."""
from __future__ import annotations

from typing import Any, Literal

MapKind = Literal["marker", "static"]

MAP_CATALOG: dict[str, dict[str, Any]] = {
    "turkiye_goller": {
        "title": "Türkiye — Tuz Gölü ve Van Gölü",
        "kind": "marker",
        "asset": "content/maps/turkiye_goller.png",
        "editor_asset": "content/maps/turkiye_goller_editor.png",
        "description": "Koordinatlı işaret ekleyerek göl veya bölge soruları.",
    },
    "turkiye_indirgenmis_sicaklik": {
        "title": "Yıllık ortalama indirgenmiş sıcaklık dağılışı",
        "kind": "static",
        "asset": "content/maps/turkiye_indirgenmis_sicaklik.png",
        "description": "Hazır tematik iklim haritası; işaret eklenmez.",
    },
}


def map_template_choices() -> list[tuple[str, str]]:
    return [("", "Harita yok")] + [
        (key, entry["title"]) for key, entry in MAP_CATALOG.items()
    ]


def get_map_entry(template: str) -> dict[str, Any] | None:
    key = (template or "").strip()
    if not key:
        return None
    return MAP_CATALOG.get(key)


def is_marker_template(template: str) -> bool:
    entry = get_map_entry(template)
    return bool(entry and entry.get("kind") == "marker")


def is_static_template(template: str) -> bool:
    entry = get_map_entry(template)
    return bool(entry and entry.get("kind") == "static")
