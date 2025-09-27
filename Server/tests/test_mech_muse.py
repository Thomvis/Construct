from __future__ import annotations

import asyncio
import json
from collections.abc import Generator
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.routers.mech_muse import provide_openai_client
from app.security import create_access_token
from app.services.usage import InMemoryUsageStore
from main import app


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

    async def create(self, **kwargs: Any) -> _StubResponse:
        self.calls.append(kwargs)
        return _StubResponse(self.payload, usage=self._usage)


class _StubOpenAI:
    def __init__(self, payload: str, usage: dict[str, int] | None = None) -> None:
        self.responses = _StubResponses(payload, usage=usage)


def _user_token(*, subject: str = "user-123") -> str:
    return create_access_token(subject)


@pytest.fixture(name="stub_openai")
def stub_openai_fixture() -> Generator[_StubOpenAI, None, None]:
    stub = _StubOpenAI(
        json.dumps({"name": "Clockwork Wolf"}),
        usage={"input_tokens": 150, "output_tokens": 60},
    )

    async def _override() -> _StubOpenAI:
        return stub

    app.dependency_overrides[provide_openai_client] = _override
    try:
        yield stub
    finally:
        app.dependency_overrides.pop(provide_openai_client, None)


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

    token = _user_token()
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post("/mech-muse/creatures/generate", json=payload, headers=headers)

    assert response.status_code == 200
    assert response.json()["name"] == "Clockwork Wolf"

    call = stub_openai.responses.calls[0]
    assert call["model"] == "gpt-4.1-mini"
    assert call["input"][0]["role"] == "system"
    assert call["input"][-1]["content"][0]["text"].startswith("Update the latest stat block")

    usage_record = asyncio.run(usage_store.get_usage("user-123"))
    assert usage_record is not None
    assert usage_record.input_tokens == 150
    assert usage_record.output_tokens == 60


def test_mech_muse_creature_generation_invalid_json(client: TestClient) -> None:
    stub = _StubOpenAI("not json")

    async def _override() -> _StubOpenAI:
        return stub

    app.dependency_overrides[provide_openai_client] = _override
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
