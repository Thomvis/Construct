# Agent Guidelines

- Favor well-maintained open-source libraries when they align with project needs and licensing.

- Breaking API changes are acceptable until Mechanical Muse launches; coordinate with app team before locking contracts.
- Use Apple's App Store Server library to fetch `signedTransactionInfo` via `get_transaction_info` and verify it with `SignedDataVerifier` when handling IAP entitlements.
- Require clients to supply a transaction identifier (preferably the original transaction id); call Apple and fail fast so clients can retry on rate limits.
