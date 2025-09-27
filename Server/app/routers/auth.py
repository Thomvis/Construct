from __future__ import annotations

from datetime import UTC, datetime

from appstoreserverlibrary.models.JWSTransactionDecodedPayload import (
    JWSTransactionDecodedPayload,
)
from fastapi import APIRouter, Depends, HTTPException, status

from ..schemas import ProtectedResponse, TokenRequest, TokenResponse
from ..security import create_access_token, get_current_subject
from ..services.apple_transactions import (
    AppleTransactionVerifier,
    TransactionVerificationError,
    get_transaction_verifier,
)
from ..services.usage import TokenUsageStore, get_usage_store
from ..settings import Clock, get_clock, get_settings

__all__ = ["router"]

router = APIRouter(tags=["auth"])


@router.post("/token", response_model=TokenResponse)
async def generate_token(
    payload: TokenRequest,
    clock: Clock = Depends(get_clock),
    verifier: AppleTransactionVerifier = Depends(get_transaction_verifier),
    usage_store: TokenUsageStore = Depends(get_usage_store),
) -> TokenResponse:
    grant_type_raw = payload.grant_type or "password"
    grant_type = grant_type_raw.lower()

    if grant_type == "password":
        return _handle_password_grant(payload, clock)

    if grant_type == "urn:app:grant:appstore-transaction-jws":
        return await _handle_jws_grant(payload, verifier, usage_store, clock)

    raise HTTPException(
        status.HTTP_400_BAD_REQUEST,
        detail=f"Unsupported grant_type: {grant_type_raw}",
    )


def _handle_password_grant(payload: TokenRequest, clock: Clock) -> TokenResponse:
    settings = get_settings()
    if payload.password != settings.admin_password:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(subject="admin", clock=clock)
    return TokenResponse(access_token=token, entitlements=())


async def _handle_jws_grant(
    payload: TokenRequest,
    verifier: AppleTransactionVerifier,
    usage_store: TokenUsageStore,
    clock: Clock,
) -> TokenResponse:
    if payload.transaction is None or payload.transaction.strip() == "":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="transaction is required")

    try:
        decoded = verifier.verify_signed_transaction(payload.transaction)
    except TransactionVerificationError as exc:
        status_code = exc.status_code or status.HTTP_400_BAD_REQUEST
        if status_code == 429:
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        elif 400 <= status_code < 500:
            status_code = status.HTTP_400_BAD_REQUEST
        else:
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        raise HTTPException(status_code=status_code, detail=str(exc)) from exc

    app_user_id = decoded.appAccountToken
    if not app_user_id:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Transaction does not include appAccountToken",
        )

    return await _issue_user_token(decoded, app_user_id, usage_store, clock)


async def _issue_user_token(
    decoded: JWSTransactionDecodedPayload,
    app_user_id: str,
    usage_store: TokenUsageStore,
    clock: Clock,
) -> TokenResponse:
    product_id = (decoded.productId or "").strip()
    if not product_id:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Transaction does not correspond to a supported product",
        )

    expires_at = _expires_at(decoded)
    if expires_at is not None and expires_at <= datetime.now(UTC):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Subscription has expired")

    transaction_id = decoded.transactionId or decoded.originalTransactionId
    if transaction_id is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Transaction identifiers missing",
        )

    original_transaction_id = decoded.originalTransactionId or transaction_id

    token = create_access_token(
        app_user_id,
        expires_at=expires_at,
        clock=clock,
    )

    expires_at_iso = expires_at.isoformat() if expires_at else None

    await usage_store.increment_usage(
        subscription_id=original_transaction_id,
        user_id=app_user_id,
        product_id=product_id,
        input_tokens=0,
        output_tokens=0,
    )

    return TokenResponse(
        access_token=token,
        entitlements=(),
        productId=product_id,
        subscriptionId=original_transaction_id,
        transactionId=transaction_id,
        expiresAt=expires_at_iso,
    )



def _expires_at(decoded: JWSTransactionDecodedPayload) -> datetime | None:
    value = decoded.expiresDate
    if value is None or value <= 0:
        return None
    return datetime.fromtimestamp(value / 1000, tz=UTC)


@router.get("/protected", response_model=ProtectedResponse)
async def protected_route(current_subject: str = Depends(get_current_subject)) -> ProtectedResponse:
    return ProtectedResponse(message=f"Hello, {current_subject}. Access granted.")
