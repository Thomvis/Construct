import os
from collections.abc import Generator
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("ADMIN_PASSWORD", "test-admin")
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "5")

from main import app, get_clock  # noqa: E402


@pytest.fixture(name="client")
def client_fixture() -> Generator[TestClient, None, None]:
    with TestClient(app) as client:
        yield client


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
