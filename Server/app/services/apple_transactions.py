from __future__ import annotations

import base64
from dataclasses import dataclass
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Iterable

from appstoreserverlibrary.api_client import APIException, AsyncAppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment as AppleEnvironment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from ..settings import Settings, get_settings

__all__ = [
    "VerifiedTransaction",
    "TransactionVerificationError",
    "get_transaction_verifier",
]


@dataclass(frozen=True)
class VerifiedTransaction:
    product_id: str
    transaction_id: str
    original_transaction_id: str
    environment: AppleEnvironment
    signed_transaction: str
    decoded_transaction: JWSTransactionDecodedPayload
    expires_at: datetime | None


class TransactionVerificationError(RuntimeError):
    def __init__(self, message: str, *, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class AppleTransactionVerifier:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = _build_api_client(settings)
        self._verifier = _build_signed_data_verifier(settings)

    async def verify_transaction(self, transaction_id: str) -> VerifiedTransaction:
        try:
            response = await self._client.get_transaction_info(transaction_id)
        except APIException as exc:  # pragma: no cover - library raises rich exceptions
            raise _from_api_exception(exc) from exc

        signed_transaction = response.signedTransactionInfo
        if signed_transaction is None:
            raise TransactionVerificationError("Apple did not return signedTransactionInfo for the provided transaction id")

        try:
            decoded = self._verifier.verify_and_decode_signed_transaction(signed_transaction)
        except VerificationException as exc:
            raise TransactionVerificationError(str(exc), status_code=400) from exc

        expires_at = _to_datetime(decoded.expiresDate)

        return VerifiedTransaction(
            product_id=decoded.productId or "",
            transaction_id=decoded.transactionId or transaction_id,
            original_transaction_id=decoded.originalTransactionId or decoded.transactionId or transaction_id,
            environment=decoded.environment or _map_environment(self._settings.apple_api_environment),
            signed_transaction=signed_transaction,
            decoded_transaction=decoded,
            expires_at=expires_at,
        )


def _from_api_exception(exc: APIException) -> TransactionVerificationError:
    if exc.api_error is not None:
        message = f"Apple API error {exc.http_status_code} ({exc.api_error.name})"
    elif exc.error_message:
        message = f"Apple API error {exc.http_status_code}: {exc.error_message}"
    else:
        message = f"Apple API error {exc.http_status_code}"
    return TransactionVerificationError(message, status_code=exc.http_status_code)


def _build_api_client(settings: Settings) -> AsyncAppStoreServerAPIClient:
    if not settings.apple_api_private_key:
        raise TransactionVerificationError("APPLE_API_PRIVATE_KEY is not configured")
    if not settings.apple_api_key_id:
        raise TransactionVerificationError("APPLE_API_KEY_ID is not configured")
    if not settings.apple_api_issuer_id:
        raise TransactionVerificationError("APPLE_API_ISSUER_ID is not configured")
    if not settings.apple_bundle_id:
        raise TransactionVerificationError("APPLE_BUNDLE_ID is not configured")

    private_key_bytes = _normalize_private_key(settings.apple_api_private_key)
    environment = _map_environment(settings.apple_api_environment)

    try:
        return AsyncAppStoreServerAPIClient(
            signing_key=private_key_bytes,
            key_id=settings.apple_api_key_id,
            issuer_id=settings.apple_api_issuer_id,
            bundle_id=settings.apple_bundle_id,
            environment=environment,
        )
    except ValueError as exc:
        raise TransactionVerificationError(str(exc)) from exc


def _build_signed_data_verifier(settings: Settings) -> SignedDataVerifier:
    bundle_id = settings.apple_bundle_id
    if not bundle_id:
        raise TransactionVerificationError("APPLE_BUNDLE_ID is not configured")

    root_certificates = list(_load_root_certificates(settings))
    if not root_certificates:
        raise TransactionVerificationError(
            "Apple root certificates are not configured. Provide APPLE_ROOT_CERT_PATHS or APPLE_ROOT_CERT_BASE64."
        )

    environment = _map_environment(settings.apple_api_environment)

    return SignedDataVerifier(
        root_certificates=root_certificates,
        enable_online_checks=settings.apple_enable_online_checks,
        environment=environment,
        bundle_id=bundle_id,
        app_apple_id=settings.apple_app_apple_id,
    )


def _normalize_private_key(raw_key: str) -> bytes:
    formatted = raw_key.strip().replace("\\n", "\n")
    if "-----BEGIN" not in formatted:
        raise TransactionVerificationError(
            "APPLE_API_PRIVATE_KEY must be provided in PEM format (including BEGIN/END headers)."
        )
    return formatted.encode("utf-8")


def _map_environment(value: str | None) -> AppleEnvironment:
    normalized = (value or "sandbox").strip().lower()
    if normalized in {"prod", "production"}:
        return AppleEnvironment.PRODUCTION
    if normalized in {"sandbox", "sand_box"}:
        return AppleEnvironment.SANDBOX
    if normalized in {"local_testing", "local-testing", "localtest"}:
        return AppleEnvironment.LOCAL_TESTING
    raise TransactionVerificationError(f"Unsupported Apple API environment: {value!r}")


def _load_root_certificates(settings: Settings) -> Iterable[bytes]:
    if settings.apple_root_cert_paths:
        for raw_path in settings.apple_root_cert_paths.split(":"):
            path = raw_path.strip()
            if not path:
                continue
            cert_path = Path(path)
            if not cert_path.exists():
                raise TransactionVerificationError(f"Apple root certificate not found: {cert_path}")
            yield cert_path.read_bytes()

    if settings.apple_root_cert_base64:
        for chunk in settings.apple_root_cert_base64.split(","):
            data = chunk.strip()
            if not data:
                continue
            try:
                yield base64.b64decode(data)
            except (ValueError, base64.binascii.Error) as exc:
                raise TransactionVerificationError("Failed to decode APPLE_ROOT_CERT_BASE64 entry") from exc


def _to_datetime(value: int | None) -> datetime | None:
    if value is None or value <= 0:
        return None
    return datetime.fromtimestamp(value / 1000, tz=UTC)


@lru_cache(maxsize=1)
def get_transaction_verifier() -> AppleTransactionVerifier:
    return AppleTransactionVerifier(get_settings())
