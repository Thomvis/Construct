from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

from .models import IAPCatalog

__all__ = ["DEFAULT_CATALOG_PATH", "load_catalog"]

DEFAULT_CATALOG_PATH = Path(__file__).with_name("products.json")


@lru_cache(maxsize=4)
def _load_catalog_cached(path: str) -> IAPCatalog:
    catalog_path = Path(path)
    raw = catalog_path.read_text(encoding="utf-8")
    data = json.loads(raw)
    return IAPCatalog.model_validate(data)


def load_catalog(path: str | Path | None = None) -> IAPCatalog:
    catalog_path = Path(path) if path is not None else DEFAULT_CATALOG_PATH
    return _load_catalog_cached(str(catalog_path))
