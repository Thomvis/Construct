from __future__ import annotations

from pydantic import BaseModel, Field
from pydantic.config import ConfigDict

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
    model_config = ConfigDict(populate_by_name=True)

    grant_type: str = Field(default="password", alias="grantType", min_length=1)
    password: str | None = Field(default=None, min_length=1)
    transaction: str | None = Field(default=None, min_length=1)


class TokenResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    access_token: str
    token_type: str = "bearer"
    entitlements: tuple[str, ...] | None = None
    product_id: str | None = Field(default=None, alias="productId")
    subscription_id: str | None = Field(default=None, alias="subscriptionId")
    transaction_id: str | None = Field(default=None, alias="transactionId")
    expires_at: str | None = Field(default=None, alias="expiresAt")


class ProtectedResponse(BaseModel):
    message: str
