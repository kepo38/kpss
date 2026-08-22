"""TG deneme soru dağılım şeması (120 soru)."""

from __future__ import annotations

from typing import Any

DEFAULT_TG_EXAM_DISTRIBUTION: dict[str, Any] = {
    "turkce": {
        "total": 30,
        "subject_slugs": ["turkce_anlam", "turkce_dilbilgisi"],
    },
    "matematik": 30,
    "tarih": 27,
    "cografya": {
        "total": 18,
        "tags": {
            "Türkiye'nin Fiziki Özellikleri": 7,
            "Ekonomik Coğrafya": 7,
            "Beşeri Coğrafya": 4,
        },
    },
    "vatandaslik": 9,
    "guncel": 6,
}

SUBJECT_SLUG_ALIASES: dict[str, list[str]] = {
    "turkce": ["turkce_anlam", "turkce_dilbilgisi"],
    "matematik": ["matematik"],
    "tarih": ["tarih"],
    "cografya": ["cografya"],
    "vatandaslik": ["vatandaslik"],
    "guncel": ["guncel", "guncel_bilgiler"],
}
