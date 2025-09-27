from __future__ import annotations

import base64
import binascii
from collections.abc import Iterable
from functools import lru_cache
from pathlib import Path

from appstoreserverlibrary.api_client import APIException, AsyncAppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment as AppleEnvironment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from ..settings import Settings, get_settings

__all__ = [
    "TransactionVerificationError",
    "get_transaction_verifier",
]


class TransactionVerificationError(RuntimeError):
    def __init__(self, message: str, *, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class AppleTransactionVerifier:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: AsyncAppStoreServerAPIClient | None = None
        self._verifier: SignedDataVerifier | None = None

    def _ensure_verifier(self) -> SignedDataVerifier:
        if self._verifier is None:
            self._verifier = _build_signed_data_verifier(self._settings)
        return self._verifier

    def verify_signed_transaction(self, signed_transaction: str) -> JWSTransactionDecodedPayload:
        if signed_transaction is None or signed_transaction.strip() == "":
            raise TransactionVerificationError("Transaction JWS is required", status_code=400)

        verifier = self._ensure_verifier()
        try:
            return verifier.verify_and_decode_signed_transaction(signed_transaction)
        except VerificationException as exc:
            raise TransactionVerificationError(str(exc), status_code=400) from exc

def _build_signed_data_verifier(settings: Settings) -> SignedDataVerifier:
    bundle_id = settings.apple_bundle_id
    if not bundle_id:
        raise TransactionVerificationError("APPLE_BUNDLE_ID is not configured")

    root_certificates = list(_load_root_certificates(settings))
    if not root_certificates:
        raise TransactionVerificationError(
            "Apple root certificates are not configured. Provide "
            "APPLE_ROOT_CERT_PATHS or APPLE_ROOT_CERT_BASE64."
        )

    environment = _map_environment(settings.apple_api_environment)

    return SignedDataVerifier(
        root_certificates=root_certificates,
        enable_online_checks=settings.apple_enable_online_checks,
        environment=environment,
        bundle_id=bundle_id,
        app_apple_id=settings.apple_app_apple_id,
    )


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
            except (ValueError, binascii.Error) as exc:
                raise TransactionVerificationError(
                    "Failed to decode APPLE_ROOT_CERT_BASE64 entry"
                ) from exc

@lru_cache(maxsize=1)
def get_transaction_verifier() -> AppleTransactionVerifier:
    return AppleTransactionVerifier(get_settings())
