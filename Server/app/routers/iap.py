from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from pydantic.config import ConfigDict
from starlette.concurrency import run_in_threadpool

from ..schemas import TokenResponse
from ..security import create_access_token, decode_token
from ..services.apple_transactions import (
    AppleTransactionVerifier,
    TransactionVerificationError,
    get_transaction_verifier,
)
from ..services.usage import TokenUsageStore, get_usage_store
from ..settings import Clock, get_clock, get_iap_catalog

__all__ = ["router"]

router = APIRouter(prefix="/iap", tags=["iap"])


class IAPProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    identifier: str = Field(serialization_alias="id")
    type: str
    display_name: str = Field(serialization_alias="displayName")
    description: str
    duration: str | None = None
    entitlements: tuple[str, ...]


class TransactionVerificationRequest(BaseModel):
    transaction_id: str = Field(alias="transactionId", min_length=1)
    app_user_id: str = Field(alias="appUserId", min_length=1)


class SubscriptionInfo(BaseModel):
    model_config = ConfigDict()

    subscription_id: str = Field(serialization_alias="subscriptionId")
    product_id: str = Field(serialization_alias="productId")
    transaction_id: str = Field(serialization_alias="transactionId")
    expires_at: str | None = Field(serialization_alias="expiresAt", default=None)
    environment: str


class ReceiptVerificationResponse(TokenResponse):
    model_config = ConfigDict()

    expires_at: str | None = Field(serialization_alias="expiresAt", default=None)
    entitlements: tuple[str, ...]
    subscription: SubscriptionInfo


@router.get("/products", response_model=list[IAPProductResponse])
async def list_products() -> list[IAPProductResponse]:
    catalog = get_iap_catalog()
    return [IAPProductResponse.model_validate(product) for product in catalog.products]


@router.post(
    "/receipts/verify",
    response_model=ReceiptVerificationResponse,
    status_code=status.HTTP_200_OK,
)
async def verify_receipt(
    payload: TransactionVerificationRequest,
    verifier: AppleTransactionVerifier = Depends(get_transaction_verifier),
    clock: Clock = Depends(get_clock),
    usage_store: TokenUsageStore = Depends(get_usage_store),
) -> ReceiptVerificationResponse:
    catalog = get_iap_catalog()
    try:
        verified = await run_in_threadpool(verifier.verify_transaction, payload.transaction_id)
    except TransactionVerificationError as exc:
        status_code = exc.status_code or status.HTTP_503_SERVICE_UNAVAILABLE
        if status_code == 429:
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        elif 400 <= status_code < 500:
            status_code = status.HTTP_400_BAD_REQUEST
        else:
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        raise HTTPException(status_code=status_code, detail=str(exc)) from exc

    product = catalog.find(verified.product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction does not correspond to a supported product",
        )

    if verified.expires_at is not None and verified.expires_at <= datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Subscription has expired",
        )

    entitlements = product.entitlements
    token = create_access_token(
        payload.app_user_id,
        clock=clock,
        token_type="user",
        entitlements=entitlements,
        scope=("mech-muse",),
        product_id=product.identifier,
        subscription_id=verified.original_transaction_id,
    )
    token_data = decode_token(token)

    subscription_info = SubscriptionInfo(
        subscription_id=verified.original_transaction_id,
        product_id=product.identifier,
        transaction_id=verified.transaction_id,
        expires_at=verified.expires_at.isoformat() if verified.expires_at else None,
        environment=verified.environment.value,
    )

    # Initialize usage document to ensure it exists even if no calls have been made yet.
    await run_in_threadpool(
        lambda: usage_store.increment_usage(
            subscription_id=verified.original_transaction_id,
            user_id=payload.app_user_id,
            product_id=product.identifier,
            input_tokens=0,
            output_tokens=0,
        )
    )

    return ReceiptVerificationResponse(
        access_token=token,
        token_type="bearer",
        expires_at=token_data.expires_at.isoformat(),
        entitlements=entitlements,
        subscription=subscription_info,
    )
