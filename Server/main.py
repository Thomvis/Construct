from __future__ import annotations

import os
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from functools import lru_cache
from typing import Any

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

Clock = Callable[[], datetime]


class Settings(BaseModel):
    admin_password: str = Field(default="change-me", min_length=1)
    jwt_secret_key: str = Field(default="change-me-too", min_length=1)
    jwt_algorithm: str = "HS256"
    access_token_exp_minutes: int = 60


@lru_cache
def get_settings() -> Settings:
    return Settings(
        admin_password=os.getenv("ADMIN_PASSWORD", "change-me"),
        jwt_secret_key=os.getenv("JWT_SECRET", "change-me-too"),
        access_token_exp_minutes=int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60")),
    )


def default_clock() -> datetime:
    return datetime.now(UTC)


def get_clock() -> Clock:
    return default_clock


class RootResponse(BaseModel):
    message: str


class HealthResponse(BaseModel):
    status: str


class TokenRequest(BaseModel):
    password: str = Field(min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class ProtectedResponse(BaseModel):
    message: str


security = HTTPBearer(auto_error=False)
app = FastAPI(title="Construct Server")

UNAUTHORIZED_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Not authenticated",
    headers={"WWW-Authenticate": "Bearer"},
)


def create_access_token(subject: str, clock: Clock | None = None) -> str:
    settings = get_settings()
    now = (clock or default_clock)()
    expires_delta = timedelta(minutes=settings.access_token_exp_minutes)
    expire_at = now + expires_delta
    payload = {"sub": subject, "exp": expire_at}
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> str:
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

    return subject


async def get_current_subject(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    if credentials is None:
        raise UNAUTHORIZED_ERROR

    if credentials.scheme.lower() != "bearer":
        raise UNAUTHORIZED_ERROR

    return decode_token(credentials.credentials)


@app.get("/", response_model=RootResponse)
async def read_root() -> RootResponse:
    return RootResponse(message="Construct server ready")


@app.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    return HealthResponse(status="ok")


@app.post("/token", response_model=TokenResponse)
async def generate_token(
    payload: TokenRequest,
    clock: Clock = Depends(get_clock),
) -> TokenResponse:
    settings = get_settings()
    if payload.password != settings.admin_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    token = create_access_token(subject="admin", clock=clock)
    return TokenResponse(access_token=token)


@app.get("/protected", response_model=ProtectedResponse)
async def protected_route(current_subject: str = Depends(get_current_subject)) -> ProtectedResponse:
    return ProtectedResponse(message=f"Hello, {current_subject}. Access granted.")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
