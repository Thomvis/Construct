import os
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient

from app.services import usage as usage_services
from app.services.usage import InMemoryUsageStore, get_usage_store
from main import app

os.environ.setdefault("ADMIN_PASSWORD", "test-admin")
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "5")
os.environ.setdefault("OPENAI_API_KEY", "test-openai-key")


@pytest.fixture(autouse=True)
def reset_usage_store_cache() -> Generator[None, None, None]:
    usage_services._get_default_store.cache_clear()
    yield
    usage_services._get_default_store.cache_clear()


@pytest.fixture
def usage_store() -> Generator[InMemoryUsageStore, None, None]:
    store = InMemoryUsageStore()
    app.dependency_overrides[get_usage_store] = lambda: store
    try:
        yield store
    finally:
        app.dependency_overrides.pop(get_usage_store, None)


@pytest.fixture
def client(usage_store: InMemoryUsageStore) -> Generator[TestClient, None, None]:
    with TestClient(app) as client:
        yield client
