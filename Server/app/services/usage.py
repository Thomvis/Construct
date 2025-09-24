from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from functools import lru_cache
from threading import Lock
from typing import Protocol

from ..settings import get_settings

__all__ = [
    "TokenUsageRecord",
    "TokenUsageStore",
    "InMemoryUsageStore",
    "FirestoreUsageStore",
    "get_usage_store",
]


@dataclass
class TokenUsageRecord:
    subscription_id: str
    user_id: str
    product_id: str
    input_tokens: int
    output_tokens: int
    updated_at: datetime


class TokenUsageStore(Protocol):
    def increment_usage(
        self,
        *,
        subscription_id: str,
        user_id: str,
        product_id: str,
        input_tokens: int,
        output_tokens: int,
    ) -> None:
        """Increment usage counters for a subscription."""

    def get_usage(self, subscription_id: str) -> TokenUsageRecord | None:
        """Return the current aggregate usage for the given subscription."""


class InMemoryUsageStore(TokenUsageStore):
    def __init__(self) -> None:
        self._lock = Lock()
        self._records: dict[str, TokenUsageRecord] = {}

    def increment_usage(
        self,
        *,
        subscription_id: str,
        user_id: str,
        product_id: str,
        input_tokens: int,
        output_tokens: int,
    ) -> None:
        now = datetime.now(UTC)
        with self._lock:
            record = self._records.get(subscription_id)
            if record is None:
                record = TokenUsageRecord(
                    subscription_id=subscription_id,
                    user_id=user_id,
                    product_id=product_id,
                    input_tokens=max(input_tokens, 0),
                    output_tokens=max(output_tokens, 0),
                    updated_at=now,
                )
                self._records[subscription_id] = record
                return

            self._records[subscription_id] = TokenUsageRecord(
                subscription_id=subscription_id,
                user_id=user_id,
                product_id=product_id,
                input_tokens=record.input_tokens + max(input_tokens, 0),
                output_tokens=record.output_tokens + max(output_tokens, 0),
                updated_at=now,
            )

    def get_usage(self, subscription_id: str) -> TokenUsageRecord | None:
        with self._lock:
            record = self._records.get(subscription_id)
            if record is None:
                return None
            return TokenUsageRecord(
                subscription_id=record.subscription_id,
                user_id=record.user_id,
                product_id=record.product_id,
                input_tokens=record.input_tokens,
                output_tokens=record.output_tokens,
                updated_at=record.updated_at,
            )


class FirestoreUsageStore(TokenUsageStore):
    def __init__(self, *, project_id: str, collection: str = "subscription_usage") -> None:
        from google.cloud import firestore

        self._client = firestore.Client(project=project_id)
        self._collection = collection
        self._firestore = firestore

    def increment_usage(
        self,
        *,
        subscription_id: str,
        user_id: str,
        product_id: str,
        input_tokens: int,
        output_tokens: int,
    ) -> None:
        doc_ref = self._client.collection(self._collection).document(subscription_id)
        updates = {
            "subscription_id": subscription_id,
            "user_id": user_id,
            "product_id": product_id,
            "input_tokens": self._firestore.Increment(max(input_tokens, 0)),
            "output_tokens": self._firestore.Increment(max(output_tokens, 0)),
            "updated_at": self._firestore.SERVER_TIMESTAMP,
        }
        doc_ref.set(updates, merge=True)

    def get_usage(self, subscription_id: str) -> TokenUsageRecord | None:
        doc = self._client.collection(self._collection).document(subscription_id).get()
        if not doc.exists:
            return None
        data = doc.to_dict() or {}
        updated_at = data.get("updated_at")
        if isinstance(updated_at, datetime):
            updated_at_dt = updated_at
        else:
            updated_at_dt = datetime.now(UTC)
        return TokenUsageRecord(
            subscription_id=subscription_id,
            user_id=str(data.get("user_id", "")),
            product_id=str(data.get("product_id", "")),
            input_tokens=int(data.get("input_tokens", 0)),
            output_tokens=int(data.get("output_tokens", 0)),
            updated_at=updated_at_dt,
        )


@lru_cache(maxsize=1)
def _get_default_store() -> TokenUsageStore:
    settings = get_settings()
    if settings.firestore_project_id:
        return FirestoreUsageStore(
            project_id=settings.firestore_project_id,
            collection=settings.firestore_usage_collection,
        )
    return InMemoryUsageStore()


def get_usage_store() -> TokenUsageStore:
    return _get_default_store()
