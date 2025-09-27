from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime
from functools import lru_cache
from typing import Any, Literal

from openai import AsyncOpenAI
from pydantic import AliasChoices, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Clock = Callable[[], datetime]

__all__ = [
    "Clock",
    "Settings",
    "default_clock",
    "get_clock",
    "get_openai_client",
    "get_settings",
]

class Settings(BaseSettings):
    model_config = SettingsConfigDict(frozen=True, env_prefix="")

    admin_password: str = Field(
        default="change-me",
        min_length=1,
        validation_alias="ADMIN_PASSWORD",
    )
    jwt_secret_key: str = Field(
        default="change-me-too",
        min_length=1,
        validation_alias="JWT_SECRET",
    )
    jwt_algorithm: str = Field(default="HS256", validation_alias="JWT_ALGORITHM")
    access_token_exp_minutes: int = Field(
        default=60,
        validation_alias="ACCESS_TOKEN_EXPIRE_MINUTES",
    )
    user_access_token_exp_minutes: int | None = Field(
        default=None,
        validation_alias="USER_ACCESS_TOKEN_EXPIRE_MINUTES",
    )
    openai_api_key: str | None = Field(
        default=None,
        validation_alias="OPENAI_API_KEY",
    )
    openai_model: str = Field(default="gpt-4.1-mini", validation_alias="OPENAI_MODEL")
    openai_base_url: str | None = Field(
        default=None,
        validation_alias="OPENAI_BASE_URL",
    )
    openai_temperature: float = Field(
        default=0.7,
        validation_alias="OPENAI_TEMPERATURE",
    )
    openai_timeout_seconds: float = Field(
        default=180.0,
        validation_alias="OPENAI_TIMEOUT_SECONDS",
    )
    openai_max_output_tokens: int | None = Field(
        default=None,
        validation_alias="OPENAI_MAX_OUTPUT_TOKENS",
    )
    apple_api_key_id: str | None = Field(
        default=None,
        validation_alias="APPLE_API_KEY_ID",
    )
    apple_api_issuer_id: str | None = Field(
        default=None,
        validation_alias="APPLE_API_ISSUER_ID",
    )
    apple_api_private_key: str | None = Field(
        default=None,
        validation_alias="APPLE_API_PRIVATE_KEY",
    )
    apple_bundle_id: str | None = Field(default=None, validation_alias="APPLE_BUNDLE_ID")
    apple_api_environment: Literal["production", "sandbox", "local_testing"] = Field(
        default="sandbox",
        validation_alias=AliasChoices("APPLE_API_ENV", "APPLE_RECEIPT_ENV"),
    )
    apple_app_apple_id: int | None = Field(
        default=None,
        validation_alias="APPLE_APP_APPLE_ID",
    )
    apple_root_cert_paths: str | None = Field(
        default=None,
        validation_alias="APPLE_ROOT_CERT_PATHS",
    )
    apple_root_cert_base64: str | None = Field(
        default=None,
        validation_alias="APPLE_ROOT_CERT_BASE64",
    )
    apple_enable_online_checks: bool = Field(
        default=False,
        validation_alias="APPLE_ENABLE_ONLINE_CHECKS",
    )
    firestore_project_id: str | None = Field(
        default=None,
        validation_alias="FIRESTORE_PROJECT_ID",
    )
    firestore_usage_collection: str = Field(
        default="subscription_usage",
        validation_alias="FIRESTORE_USAGE_COLLECTION",
    )

    @field_validator(
        "user_access_token_exp_minutes",
        "openai_max_output_tokens",
        "apple_app_apple_id",
        mode="before",
    )
    @classmethod
    def _empty_string_to_none(cls, value: Any) -> Any:
        if isinstance(value, str) and value.strip() == "":
            return None
        return value

    @field_validator("apple_enable_online_checks", mode="before")
    @classmethod
    def _bool_from_string(cls, value: Any) -> Any:
        if isinstance(value, str):
            stripped = value.strip()
            if stripped == "":
                return False
            return stripped.lower() in {"1", "true", "yes", "on"}
        return value

    @field_validator("apple_api_environment", mode="before")
    @classmethod
    def _normalize_apple_env(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip().lower()
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()


def default_clock() -> datetime:
    return datetime.now(UTC)


def get_clock() -> Clock:
    return default_clock


@lru_cache
def _create_openai_client(
    api_key: str,
    base_url: str | None,
    timeout_seconds: float,
) -> AsyncOpenAI:
    kwargs: dict[str, Any] = {"api_key": api_key, "timeout": timeout_seconds}
    if base_url:
        kwargs["base_url"] = base_url
    return AsyncOpenAI(**kwargs)


def get_openai_client() -> AsyncOpenAI:
    settings = get_settings()
    if settings.openai_api_key is None:
        raise RuntimeError("OpenAI API key is not configured")
    return _create_openai_client(
        settings.openai_api_key,
        settings.openai_base_url,
        settings.openai_timeout_seconds,
    )


