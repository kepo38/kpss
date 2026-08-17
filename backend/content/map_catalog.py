"""Static map assets and template metadata for geography questions."""
from __future__ import annotations

from typing import Any, Iterator, Literal

MapKind = Literal["marker", "static"]

MAP_CATALOG: dict[str, dict[str, Any]] = {
    "turkiye_goller": {
        "title": "Türkiye — Tuz Gölü ve Van Gölü",
        "kind": "marker",
        "asset": "content/maps/turkiye_goller.png",
        "editor_asset": "content/maps/turkiye_goller_editor.png",
        "description": "Koordinatlı işaret ekleyerek göl veya bölge soruları.",
        "source": "static",
        "builtin": True,
    },
    "turkiye_indirgenmis_sicaklik": {
        "title": "Yıllık ortalama indirgenmiş sıcaklık dağılışı",
        "kind": "static",
        "asset": "content/maps/turkiye_indirgenmis_sicaklik.png",
        "description": "Hazır tematik iklim haritası; işaret eklenmez.",
        "source": "static",
        "builtin": True,
    },
}


def _entry_from_db(obj: Any) -> dict[str, Any]:
    image_path = obj.image.path if obj.image else ""
    image_url = obj.image.url if obj.image else ""
    editor = obj.editor_image if obj.editor_image else obj.image
    editor_path = editor.path if editor else image_path
    editor_url = editor.url if editor else image_url
    return {
        "title": obj.title,
        "kind": obj.kind,
        "description": obj.description or "",
        "source": "media",
        "builtin": False,
        "asset": image_path,
        "editor_asset": editor_path,
        "url": image_url,
        "editor_url": editor_url,
        "path": image_path,
        "editor_path": editor_path,
    }


def iter_map_entries() -> Iterator[tuple[str, dict[str, Any]]]:
    """Yield (slug, entry) for builtins then DB maps (builtins win on collision)."""
    seen: set[str] = set()
    for key, entry in MAP_CATALOG.items():
        seen.add(key)
        yield key, {**entry, "source": entry.get("source", "static"), "builtin": True}

    try:
        from django.db.utils import OperationalError, ProgrammingError

        from .models import MapTemplate

        for obj in MapTemplate.objects.all().order_by("title"):
            if obj.slug in seen:
                continue
            seen.add(obj.slug)
            yield obj.slug, _entry_from_db(obj)
    except (OperationalError, ProgrammingError):
        return
    except Exception:
        return


def map_template_choices() -> list[tuple[str, str]]:
    return [("", "Harita yok")] + [
        (key, entry["title"]) for key, entry in iter_map_entries()
    ]


def get_map_entry(template: str) -> dict[str, Any] | None:
    key = (template or "").strip()
    if not key:
        return None
    if key in MAP_CATALOG:
        entry = dict(MAP_CATALOG[key])
        entry.setdefault("source", "static")
        entry.setdefault("builtin", True)
        return entry
    try:
        from django.db.utils import OperationalError, ProgrammingError

        from .models import MapTemplate

        obj = MapTemplate.objects.filter(slug=key).first()
    except (OperationalError, ProgrammingError):
        return None
    except Exception:
        return None
    if not obj:
        return None
    return _entry_from_db(obj)


def is_marker_template(template: str) -> bool:
    entry = get_map_entry(template)
    return bool(entry and entry.get("kind") == "marker")


def is_static_template(template: str) -> bool:
    entry = get_map_entry(template)
    return bool(entry and entry.get("kind") == "static")
