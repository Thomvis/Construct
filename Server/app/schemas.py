from __future__ import annotations

from pydantic import BaseModel, Field

__all__ = [
    "HealthResponse",
    "ProtectedResponse",
    "RootResponse",
    "TokenRequest",
    "TokenResponse",
]


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
