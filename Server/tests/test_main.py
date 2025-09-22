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
from main import app, get_clock  # noqa: E402


class _StubResponse:
    def __init__(self, payload: str) -> None:
        self.output_text = payload
        self.output: list[Any] = []


class _StubResponses:
    def __init__(self, payload: str) -> None:
        self.payload = payload
        self.calls: list[dict[str, Any]] = []

    def create(self, **kwargs: Any) -> _StubResponse:
        self.calls.append(kwargs)
        return _StubResponse(self.payload)


class _StubOpenAI:
    def __init__(self, payload: str) -> None:
        self.responses = _StubResponses(payload)


@pytest.fixture(name="client")
def client_fixture() -> Generator[TestClient, None, None]:
    with TestClient(app) as client:
        yield client


@pytest.fixture(name="stub_openai")
def stub_openai_fixture() -> Generator[_StubOpenAI, None, None]:
    stub = _StubOpenAI(json.dumps({"name": "Clockwork Wolf"}))
    app.dependency_overrides[provide_openai_client] = lambda: stub
    try:
        yield stub
    finally:
        app.dependency_overrides.pop(provide_openai_client, None)


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


def test_mech_muse_creature_generation(client: TestClient, stub_openai: _StubOpenAI) -> None:
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

    response = client.post("/mech-muse/creatures/generate", json=payload)

    assert response.status_code == 200
    assert response.json()["name"] == "Clockwork Wolf"

    call = stub_openai.responses.calls[0]
    assert call["model"] == "gpt-4.1-mini"
    assert call["input"][0]["role"] == "system"
    assert call["input"][-1]["content"][0]["text"].startswith("Update the latest stat block")


def test_mech_muse_creature_generation_invalid_json(client: TestClient) -> None:
    stub = _StubOpenAI("not json")
    app.dependency_overrides[provide_openai_client] = lambda: stub
    try:
        payload = {"instructions": "Make it gentle.", "base": {"name": "Ogre"}}
        response = client.post("/mech-muse/creatures/generate", json=payload)
    finally:
        app.dependency_overrides.pop(provide_openai_client, None)

    assert response.status_code == 502
    assert response.json()["detail"] == "OpenAI response was not valid JSON"
