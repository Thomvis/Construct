from __future__ import annotations

from app.main import app, create_app  # noqa: F401 re-export for uvicorn entrypoint
from app.settings import get_clock, get_openai_client, get_settings

__all__ = [
    "app",
    "create_app",
    "get_clock",
    "get_openai_client",
    "get_settings",
]


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
