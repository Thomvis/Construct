"""Construct server application package."""

__all__ = ["create_app"]

from .main import create_app  # noqa: E402  (re-export for convenience)
