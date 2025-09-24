import json
import os
from collections.abc import Generator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("ADMIN_PASSWORD", "test-admin")
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "5")
os.environ.setdefault("OPENAI_API_KEY", "test-openai-key")

from app.routers.mech_muse import provide_openai_client  # noqa: E402
from app.security import create_access_token, decode_token  # noqa: E402
from app.services.apple_transactions import (  # noqa: E402
    TransactionVerificationError,
    VerifiedTransaction,
    get_transaction_verifier,
)
from app.services.usage import InMemoryUsageStore, get_usage_store  # noqa: E402
from app.services import usage as usage_services  # noqa: E402
from main import app, get_clock  # noqa: E402

from appstoreserverlibrary.models.Environment import Environment as AppleEnvironment  # noqa: E402
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import (  # noqa: E402
    JWSTransactionDecodedPayload,
)


class _StubResponse:
    def __init__(self, payload: str, usage: dict[str, int] | None = None) -> None:
        self.output_text = payload
        self.output: list[Any] = []
        self.usage = usage or {"input_tokens": 0, "output_tokens": 0}


class _StubResponses:
    def __init__(self, payload: str, usage: dict[str, int] | None = None) -> None:
        self.payload = payload
        self.calls: list[dict[str, Any]] = []
        self._usage = usage or {"input_tokens": 0, "output_tokens": 0}

    def create(self, **kwargs: Any) -> _StubResponse:
        self.calls.append(kwargs)
        return _StubResponse(self.payload, usage=self._usage)


class _StubOpenAI:
    def __init__(self, payload: str, usage: dict[str, int] | None = None) -> None:
        self.responses = _StubResponses(payload, usage=usage)


class _StubTransactionVerifier:
    def __init__(self, result: VerifiedTransaction) -> None:
        self.result = result
        self.calls: list[str] = []

    def verify_transaction(self, transaction_id: str) -> VerifiedTransaction:
        self.calls.append(transaction_id)
        return self.result


def _user_token(
    *,
    subject: str = "user-123",
    product_id: str = "com.construct.mechmuse.monthly",
    subscription_id: str = "sub-123",
) -> str:
    return create_access_token(
        subject,
        entitlements=("mechanical_muse",),
        token_type="user",
        product_id=product_id,
        subscription_id=subscription_id,
    )


def _make_verified_transaction(
    *,
    product_id: str = "com.construct.mechmuse.monthly",
    transaction_id: str = "trans-123",
    original_transaction_id: str = "original-123",
    expires_in: timedelta | None = timedelta(days=30),
) -> VerifiedTransaction:
    expires_at = None
    expires_ms = None
    if expires_in is not None:
        expires_at_dt = datetime.now(UTC) + expires_in
        expires_at = expires_at_dt
        expires_ms = int(expires_at_dt.timestamp() * 1000)
    decoded = JWSTransactionDecodedPayload(
        productId=product_id,
        transactionId=transaction_id,
        originalTransactionId=original_transaction_id,
        environment=AppleEnvironment.SANDBOX,
        expiresDate=expires_ms,
    )
    return VerifiedTransaction(
        product_id=product_id,
        transaction_id=transaction_id,
        original_transaction_id=original_transaction_id,
        environment=AppleEnvironment.SANDBOX,
        signed_transaction="signed-transaction",
        decoded_transaction=decoded,
        expires_at=expires_at,
    )


@pytest.fixture(name="client")
def client_fixture(usage_store: InMemoryUsageStore) -> Generator[TestClient, None, None]:
    with TestClient(app) as client:
        yield client


@pytest.fixture(name="stub_openai")
def stub_openai_fixture() -> Generator[_StubOpenAI, None, None]:
    stub = _StubOpenAI(
        json.dumps({"name": "Clockwork Wolf"}),
        usage={"input_tokens": 150, "output_tokens": 60},
    )
    app.dependency_overrides[provide_openai_client] = lambda: stub
    try:
        yield stub
    finally:
        app.dependency_overrides.pop(provide_openai_client, None)


@pytest.fixture(autouse=True)
def reset_usage_store_cache() -> Generator[None, None, None]:
    usage_services._get_default_store.cache_clear()
    yield
    usage_services._get_default_store.cache_clear()


@pytest.fixture(name="usage_store")
def usage_store_fixture() -> Generator[InMemoryUsageStore, None, None]:
    store = InMemoryUsageStore()
    app.dependency_overrides[get_usage_store] = lambda: store
    try:
        yield store
    finally:
        app.dependency_overrides.pop(get_usage_store, None)


@pytest.fixture(name="stub_transaction_verifier")
def stub_transaction_verifier_fixture() -> Generator[_StubTransactionVerifier, None, None]:
    result = _make_verified_transaction()
    stub = _StubTransactionVerifier(result)
    app.dependency_overrides[get_transaction_verifier] = lambda: stub
    try:
        yield stub
    finally:
        app.dependency_overrides.pop(get_transaction_verifier, None)


def test_read_root(client: TestClient) -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Construct server ready"}


def test_health_check(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


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


def test_mech_muse_creature_generation(
    client: TestClient,
    stub_openai: _StubOpenAI,
    usage_store: InMemoryUsageStore,
) -> None:
    payload = {
        "instructions": "Make the creature tougher.",
        "base": {"name": "Dire Wolf"},
        "revisions": [
            {
                "prompt": "Give it metal armor.",
                "stat_block": {"name": "Armored Wolf", "armor_class": 18},
            }
        ],
    }

    token = _user_token(subscription_id="usage-123")
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post("/mech-muse/creatures/generate", json=payload, headers=headers)

    assert response.status_code == 200
    assert response.json()["name"] == "Clockwork Wolf"

    call = stub_openai.responses.calls[0]
    assert call["model"] == "gpt-4.1-mini"
    assert call["input"][0]["role"] == "system"
    assert call["input"][-1]["content"][0]["text"].startswith("Update the latest stat block")

    usage_record = usage_store.get_usage("usage-123")
    assert usage_record is not None
    assert usage_record.input_tokens == 150
    assert usage_record.output_tokens == 60


def test_mech_muse_creature_generation_invalid_json(client: TestClient) -> None:
    stub = _StubOpenAI("not json")
    app.dependency_overrides[provide_openai_client] = lambda: stub
    try:
        payload = {"instructions": "Make it gentle.", "base": {"name": "Ogre"}}
        response = client.post(
            "/mech-muse/creatures/generate",
            json=payload,
            headers={"Authorization": f"Bearer {_user_token()}"},
        )
    finally:
        app.dependency_overrides.pop(provide_openai_client, None)

    assert response.status_code == 502
    assert response.json()["detail"] == "OpenAI response was not valid JSON"


def test_mech_muse_requires_auth(client: TestClient) -> None:
    payload = {"instructions": "Test"}
    response = client.post("/mech-muse/creatures/generate", json=payload)
    assert response.status_code == 401
    assert response.json()["detail"] == "Not authenticated"


def test_iap_products_endpoint(client: TestClient) -> None:
    response = client.get("/iap/products")
    assert response.status_code == 200

    data = response.json()
    assert isinstance(data, list)
    assert any(item["id"] == "com.construct.mechmuse.monthly" for item in data)


def test_verify_receipt_issues_token(
    client: TestClient,
    stub_transaction_verifier: _StubTransactionVerifier,
    usage_store: InMemoryUsageStore,
) -> None:
    payload = {
        "transactionId": "trans-123",
        "appUserId": "user-abc",
    }

    response = client.post("/iap/receipts/verify", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["subscription"]["subscriptionId"] == "original-123"
    assert data["subscription"]["productId"] == "com.construct.mechmuse.monthly"
    assert data["subscription"]["transactionId"] == "trans-123"

    token_data = decode_token(data["access_token"])
    assert token_data.entitlements == ("mechanical_muse",)
    assert token_data.subscription_id == "original-123"
    assert token_data.product_id == "com.construct.mechmuse.monthly"

    usage_record = usage_store.get_usage("original-123")
    assert usage_record is not None
    assert usage_record.input_tokens == 0
    assert usage_record.output_tokens == 0

    assert stub_transaction_verifier.calls == [payload["transactionId"]]


def test_verify_receipt_rejects_expired_subscription(
    client: TestClient,
    usage_store: InMemoryUsageStore,
) -> None:
    expired_verifier = _StubTransactionVerifier(
        _make_verified_transaction(expires_in=timedelta(seconds=-60))
    )
    app.dependency_overrides[get_transaction_verifier] = lambda: expired_verifier
    try:
        payload = {"transactionId": "trans-expired", "appUserId": "user-abc"}
        response = client.post("/iap/receipts/verify", json=payload)
    finally:
        app.dependency_overrides.pop(get_transaction_verifier, None)

    assert response.status_code == 403
    assert response.json()["detail"] == "Subscription has expired"
    assert usage_store.get_usage("original-123") is None


def test_verify_receipt_propagates_apple_errors(client: TestClient) -> None:
    class _FailingVerifier:
        def verify_transaction(self, transaction_id: str) -> VerifiedTransaction:
            raise TransactionVerificationError("Rate limited", status_code=429)

    app.dependency_overrides[get_transaction_verifier] = _FailingVerifier
    try:
        payload = {"transactionId": "trans-123", "appUserId": "user-abc"}
        response = client.post("/iap/receipts/verify", json=payload)
    finally:
        app.dependency_overrides.pop(get_transaction_verifier, None)

    assert response.status_code == 503
    assert response.json()["detail"] == "Rate limited"
