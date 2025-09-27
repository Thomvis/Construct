from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta

import pytest
from appstoreserverlibrary.models.Environment import Environment as AppleEnvironment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import (
    JWSTransactionDecodedPayload,
)
from fastapi.testclient import TestClient

from app.security import decode_token
from app.services.apple_transactions import (
    TransactionVerificationError,
    get_transaction_verifier,
)
from app.services.usage import InMemoryUsageStore
from main import app, get_clock


def _make_transaction_payload(
    *,
    product_id: str = "com.construct.mechmuse.monthly",
    transaction_id: str = "trans-123",
    original_transaction_id: str = "original-123",
    expires_in: timedelta | None = timedelta(days=30),
    app_account_token: str | None = None,
) -> JWSTransactionDecodedPayload:
    expires_ms = None
    if expires_in is not None:
        expires_at_dt = datetime.now(UTC) + expires_in
        expires_ms = int(expires_at_dt.timestamp() * 1000)
    decoded = JWSTransactionDecodedPayload(
        productId=product_id,
        transactionId=transaction_id,
        originalTransactionId=original_transaction_id,
        environment=AppleEnvironment.SANDBOX,
        expiresDate=expires_ms,
    )
    if app_account_token is not None:
        decoded.appAccountToken = app_account_token
    return decoded


class _StubTransactionVerifier:
    def __init__(self, result: JWSTransactionDecodedPayload) -> None:
        self.result = result
        self.signed_calls: list[str] = []

    def verify_signed_transaction(self, transaction: str) -> JWSTransactionDecodedPayload:
        self.signed_calls.append(transaction)
        return self.result


def test_token_generation(client: TestClient) -> None:
    response = client.post("/token", json={"password": "test-admin"})
    data = response.json()

    assert response.status_code == 200
    assert data["token_type"] == "bearer"
    assert "access_token" in data


def test_token_generation_invalid_password(client: TestClient) -> None:
    response = client.post("/token", json={"password": "wrong"})

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid credentials"


def test_protected_endpoint_requires_auth(client: TestClient) -> None:
    response = client.get("/protected")

    assert response.status_code == 401
    assert response.json()["detail"] == "Not authenticated"


def test_protected_endpoint_with_token(client: TestClient) -> None:
    token_response = client.post("/token", json={"password": "test-admin"})
    token = token_response.json()["access_token"]

    response = client.get("/protected", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["message"].startswith("Hello, admin")


def test_expired_token_is_rejected(client: TestClient) -> None:
    expired_reference = datetime.now(UTC) - timedelta(minutes=120)

    def past_clock() -> datetime:
        return expired_reference

    app.dependency_overrides[get_clock] = lambda: past_clock
    try:
        token_response = client.post("/token", json={"password": "test-admin"})
    finally:
        app.dependency_overrides.pop(get_clock, None)

    token = token_response.json()["access_token"]
    response = client.get("/protected", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"] == "Token has expired"


def test_token_transaction_jws_grant(
    client: TestClient,
    usage_store: InMemoryUsageStore,
) -> None:
    verified = _make_transaction_payload(transaction_id="trans-jws", app_account_token="user-jws")
    stub = _StubTransactionVerifier(verified)
    app.dependency_overrides[get_transaction_verifier] = lambda: stub
    try:
        payload = {
            "grantType": "urn:app:grant:appstore-transaction-jws",
            "transaction": "signed-jws",
        }
        response = client.post("/token", json=payload)
    finally:
        app.dependency_overrides.pop(get_transaction_verifier, None)

    assert response.status_code == 200
    data = response.json()
    assert data["transactionId"] == "trans-jws"
    assert data["subscriptionId"] == "original-123"
    assert stub.signed_calls == ["signed-jws"]

    token_data = decode_token(data["access_token"])
    assert token_data.subject == "user-jws"

    usage_record = asyncio.run(usage_store.get_usage("original-123"))
    assert usage_record is not None
    assert usage_record.input_tokens == 0
    assert usage_record.output_tokens == 0


def test_token_transaction_jws_requires_transaction(client: TestClient) -> None:
    response = client.post(
        "/token",
        json={"grantType": "urn:app:grant:appstore-transaction-jws"},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "transaction is required"


def test_token_transaction_jws_requires_app_account_token(client: TestClient) -> None:
    verified = _make_transaction_payload(transaction_id="trans-jws", app_account_token=None)
    stub = _StubTransactionVerifier(verified)
    app.dependency_overrides[get_transaction_verifier] = lambda: stub
    try:
        response = client.post(
            "/token",
            json={
                "grantType": "urn:app:grant:appstore-transaction-jws",
                "transaction": "signed-jws",
            },
        )
    finally:
        app.dependency_overrides.pop(get_transaction_verifier, None)

    assert response.status_code == 400
    assert response.json()["detail"] == "Transaction does not include appAccountToken"


def test_token_transaction_jws_propagates_apple_errors(client: TestClient) -> None:
    class _FailingVerifier:
        def verify_signed_transaction(self, transaction: str) -> JWSTransactionDecodedPayload:
            raise TransactionVerificationError("Rate limited", status_code=429)

    app.dependency_overrides[get_transaction_verifier] = _FailingVerifier
    try:
        response = client.post(
            "/token",
            json={
                "grantType": "urn:app:grant:appstore-transaction-jws",
                "transaction": "signed-jws",
            },
        )
    finally:
        app.dependency_overrides.pop(get_transaction_verifier, None)

    assert response.status_code == 503
    assert response.json()["detail"] == "Rate limited"


@pytest.mark.parametrize("endpoint", ["/", "/health"])
def test_public_endpoints(client: TestClient, endpoint: str) -> None:
    response = client.get(endpoint)
    assert response.status_code == 200
