from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .settings import Clock, default_clock, get_settings

__all__ = [
    "UNAUTHORIZED_ERROR",
    "create_access_token",
    "decode_token",
    "TokenData",
    "get_current_token",
    "get_current_subject",
    "require_entitlement",
    "security",
]

security = HTTPBearer(auto_error=False)

UNAUTHORIZED_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Not authenticated",
    headers={"WWW-Authenticate": "Bearer"},
)


@dataclass(frozen=True)
class TokenData:
    subject: str
    expires_at: datetime
    scopes: tuple[str, ...]
    entitlements: tuple[str, ...]
    token_type: str | None
    product_id: str | None
    subscription_id: str | None


def create_access_token(
    subject: str,
    expires_at: datetime | None = None,
    *,
    clock: Clock | None = None,
) -> str:
    settings = get_settings()
    now = (clock or default_clock)()

    user_minutes = settings.user_access_token_exp_minutes
    if expires_at is not None:
        expire_at = expires_at
        if expire_at.tzinfo is None:
            expire_at = expire_at.replace(tzinfo=UTC)
        else:
            expire_at = expire_at.astimezone(UTC)
        if user_minutes is not None:
            cap_at = now + timedelta(minutes=user_minutes)
            if expire_at > cap_at:
                expire_at = cap_at
    else:
        minutes = user_minutes or settings.access_token_exp_minutes
        expire_at = now + timedelta(minutes=minutes)

    payload: dict[str, Any] = {"sub": subject, "exp": expire_at}
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> TokenData:
    settings = get_settings()
    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    subject = payload.get("sub")
    if not isinstance(subject, str):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    expires_at_raw = payload.get("exp")
    expires_at = _parse_exp_claim(expires_at_raw)
    scopes = _parse_claim_list(payload.get("scope"))
    entitlements = _parse_claim_list(payload.get("entitlements"))
    raw_token_type = payload.get("token_type")
    token_type = raw_token_type if isinstance(raw_token_type, str) else None

    raw_product_id = payload.get("product_id")
    product_id = raw_product_id if isinstance(raw_product_id, str) else None

    raw_subscription_id = payload.get("subscription_id")
    subscription_id = raw_subscription_id if isinstance(raw_subscription_id, str) else None

    return TokenData(
        subject=subject,
        expires_at=expires_at,
        scopes=scopes,
        entitlements=entitlements,
        token_type=token_type,
        product_id=product_id,
        subscription_id=subscription_id,
    )


async def get_current_subject(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    if credentials is None:
        raise UNAUTHORIZED_ERROR

    if credentials.scheme.lower() != "bearer":
        raise UNAUTHORIZED_ERROR

    token = decode_token(credentials.credentials)
    return token.subject


async def get_current_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> TokenData:
    if credentials is None:
        raise UNAUTHORIZED_ERROR

    if credentials.scheme.lower() != "bearer":
        raise UNAUTHORIZED_ERROR

    return decode_token(credentials.credentials)


def require_entitlement(entitlement: str) -> Callable[[TokenData], Awaitable[TokenData]]:
    async def dependency(token: TokenData = Depends(get_current_token)) -> TokenData:
        if entitlement not in token.entitlements:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Missing required entitlement",
            )
        return token

    return dependency


def _parse_claim_list(value: Any) -> tuple[str, ...]:
    if isinstance(value, str):
        return (value,)
    if isinstance(value, (list, tuple)):
        result: list[str] = []
        for item in value:
            if isinstance(item, str) and item not in result:
                result.append(item)
        return tuple(result)
    return ()


def _parse_exp_claim(value: Any) -> datetime:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(int(value), tz=UTC)
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token expiration missing",
        headers={"WWW-Authenticate": "Bearer"},
    )
