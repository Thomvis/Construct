from __future__ import annotations

import os
from collections.abc import Callable
from datetime import UTC, datetime
from functools import lru_cache
from typing import Any, Literal

from openai import OpenAI
from pydantic import BaseModel, Field
from pydantic.config import ConfigDict

from .iap.catalog import load_catalog
from .iap.models import IAPCatalog

Clock = Callable[[], datetime]

__all__ = [
    "Clock",
    "Settings",
    "default_clock",
    "get_clock",
    "get_openai_client",
    "get_iap_catalog",
    "get_settings",
]


def _parse_optional_int(value: str | None) -> int | None:
    if value is None or value.strip() == "":
        return None
    return int(value)


def _parse_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class Settings(BaseModel):
    model_config = ConfigDict(frozen=True)

    admin_password: str = Field(default="change-me", min_length=1)
    jwt_secret_key: str = Field(default="change-me-too", min_length=1)
    jwt_algorithm: str = "HS256"
    access_token_exp_minutes: int = 60
    user_access_token_exp_minutes: int | None = None
    openai_api_key: str | None = None
    openai_model: str = "gpt-4.1-mini"
    openai_base_url: str | None = None
    openai_temperature: float = 0.7
    openai_timeout_seconds: float = 180.0
    openai_max_output_tokens: int | None = None
    apple_api_key_id: str | None = None
    apple_api_issuer_id: str | None = None
    apple_api_private_key: str | None = None
    apple_bundle_id: str | None = None
    apple_api_environment: Literal["production", "sandbox", "local_testing"] = "sandbox"
    apple_app_apple_id: int | None = None
    apple_root_cert_paths: str | None = None
    apple_root_cert_base64: str | None = None
    apple_enable_online_checks: bool = False
    firestore_project_id: str | None = None
    firestore_usage_collection: str = "subscription_usage"
    iap_catalog_path: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings(
        admin_password=os.getenv("ADMIN_PASSWORD", "change-me"),
        jwt_secret_key=os.getenv("JWT_SECRET", "change-me-too"),
        access_token_exp_minutes=int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60")),
        user_access_token_exp_minutes=_parse_optional_int(os.getenv("USER_ACCESS_TOKEN_EXPIRE_MINUTES")),
        openai_api_key=os.getenv("OPENAI_API_KEY"),
        openai_model=os.getenv("OPENAI_MODEL", "gpt-4.1-mini"),
        openai_base_url=os.getenv("OPENAI_BASE_URL"),
        openai_temperature=float(os.getenv("OPENAI_TEMPERATURE", "0.7")),
        openai_timeout_seconds=float(os.getenv("OPENAI_TIMEOUT_SECONDS", "180")),
        openai_max_output_tokens=_parse_optional_int(os.getenv("OPENAI_MAX_OUTPUT_TOKENS")),
        apple_api_key_id=os.getenv("APPLE_API_KEY_ID"),
        apple_api_issuer_id=os.getenv("APPLE_API_ISSUER_ID"),
        apple_api_private_key=os.getenv("APPLE_API_PRIVATE_KEY"),
        apple_bundle_id=os.getenv("APPLE_BUNDLE_ID"),
        apple_api_environment=os.getenv("APPLE_API_ENV", os.getenv("APPLE_RECEIPT_ENV", "sandbox")).lower(),
        apple_app_apple_id=_parse_optional_int(os.getenv("APPLE_APP_APPLE_ID")),
        apple_root_cert_paths=os.getenv("APPLE_ROOT_CERT_PATHS"),
        apple_root_cert_base64=os.getenv("APPLE_ROOT_CERT_BASE64"),
        apple_enable_online_checks=_parse_bool(os.getenv("APPLE_ENABLE_ONLINE_CHECKS"), default=False),
        firestore_project_id=os.getenv("FIRESTORE_PROJECT_ID"),
        firestore_usage_collection=os.getenv("FIRESTORE_USAGE_COLLECTION", "subscription_usage"),
        iap_catalog_path=os.getenv("IAP_CATALOG_PATH"),
    )


def default_clock() -> datetime:
    return datetime.now(UTC)


def get_clock() -> Clock:
    return default_clock


@lru_cache
def _create_openai_client(
    api_key: str,
    base_url: str | None,
    timeout_seconds: float,
) -> OpenAI:
    kwargs: dict[str, Any] = {"api_key": api_key, "timeout": timeout_seconds}
    if base_url:
        kwargs["base_url"] = base_url
    return OpenAI(**kwargs)


def get_openai_client() -> OpenAI:
    settings = get_settings()
    if settings.openai_api_key is None:
        raise RuntimeError("OpenAI API key is not configured")
    return _create_openai_client(
        settings.openai_api_key,
        settings.openai_base_url,
        settings.openai_timeout_seconds,
    )


@lru_cache
def get_iap_catalog() -> IAPCatalog:
    settings = get_settings()
    if settings.iap_catalog_path:
        return load_catalog(settings.iap_catalog_path)
    return load_catalog()
