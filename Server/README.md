# Construct Server

A minimal FastAPI service managed with [uv](https://github.com/astral-sh/uv) and ready for deployment to Google Cloud Run.

## Prerequisites
- Python 3.11+ (managed via `uv`)
- [uv CLI](https://github.com/astral-sh/uv) installed locally
- [Docker](https://www.docker.com/) for container builds
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated to your GCP project for deployment

## Configuration
Environment variables configure authentication, in-app purchase verification, usage tracking, and OpenAI access:
- `ADMIN_PASSWORD`: Magic password that issues an admin JWT (default `change-me`).
- `JWT_SECRET`: Symmetric signing key for JWTs (default `change-me-too`).
- `ACCESS_TOKEN_EXPIRE_MINUTES`: Lifetime for issued tokens (default `60`).
- `USER_ACCESS_TOKEN_EXPIRE_MINUTES`: Optional override for customer access tokens (defaults to `ACCESS_TOKEN_EXPIRE_MINUTES`).
- `OPENAI_API_KEY`: API key used for Mechanical Muse requests (**required** for Mech Muse endpoints).
- `OPENAI_MODEL`: OpenAI Responses model to use (default `gpt-4.1-mini`).
- `OPENAI_TEMPERATURE`: Sampling temperature when talking to OpenAI (default `0.7`).
- `OPENAI_TIMEOUT_SECONDS`: HTTP timeout when calling OpenAI (default `180`).
- `OPENAI_MAX_OUTPUT_TOKENS`: Optional cap on OpenAI completion tokens.
- `APPLE_API_KEY_ID`: The key identifier for your App Store Connect in-app purchase key.
- `APPLE_API_ISSUER_ID`: The issuer identifier associated with your App Store Connect key.
- `APPLE_API_PRIVATE_KEY`: The PEM-encoded private key downloaded from App Store Connect (escape newlines when storing in env vars).
- `APPLE_BUNDLE_ID`: Bundle identifier of the app whose transactions you are validating.
- `APPLE_API_ENV`: App Store Server API environment (`sandbox`, `production`, or `local_testing`; default `sandbox`).
- `APPLE_APP_APPLE_ID`: Optional App Store numeric identifier for the app; required when calling production.
- `APPLE_ROOT_CERT_PATHS`: Optional colon-separated list of filesystem paths to Apple root certificates (DER or PEM) used to validate signed transactions.
- `APPLE_ROOT_CERT_BASE64`: Optional comma-separated list of base64-encoded DER certificates (alternative to `APPLE_ROOT_CERT_PATHS`).
- `APPLE_ENABLE_ONLINE_CHECKS`: Set to `true` to enable OCSP checks when verifying Apple certificates (defaults to `false`).
- `FIRESTORE_PROJECT_ID`: When set, token usage totals are persisted to this Firestore project; otherwise an in-memory store is used.
- `FIRESTORE_USAGE_COLLECTION`: Firestore collection used for subscription usage aggregation (default `subscription_usage`).

Override these defaults in local development (for example via a `.env` file or export statements) and always provide secure values in production.

## Local development
```bash
export ADMIN_PASSWORD="your-local-password"
export JWT_SECRET="replace-with-a-random-secret"
export OPENAI_API_KEY="sk-..."
uv sync
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Visit http://localhost:8000 to see the root endpoint and http://localhost:8000/docs for the interactive API docs.

Install development tooling (mypy, ruff, pytest, httpx) when needed:
```bash
uv sync --extra dev
```

## Authentication workflow
Fetch an access token:
```bash
curl -X POST http://localhost:8000/token \
  -H "Content-Type: application/json" \
  -d '{"password": "your-local-password"}'
```
Use the token to access the protected endpoint:
```bash
TOKEN="<copy-from-token-response>"
curl http://localhost:8000/protected -H "Authorization: Bearer ${TOKEN}"
```

## Mech Muse endpoints
The Mechanical Muse API is grouped under `/mech-muse` and requires an authenticated bearer token. Tokens can be created via the admin password grant or by submitting an App Store transaction JWS.

`POST /mech-muse/creatures/generate` issues a new creature stat block using OpenAI. Example request:
```json
{
  "instructions": "Make the dire wolf tougher.",
  "base": { "name": "Dire Wolf" },
  "revisions": [
    {
      "prompt": "Give it metal armor.",
      "stat_block": { "name": "Armored Wolf", "armorClass": 18 }
    }
  ]
}
```
The response returns a simplified stat block matching the supplied schema. Provide `OPENAI_API_KEY` (and optionally `OPENAI_MODEL`, etc.) before calling the endpoint. Token usage (input/output tokens) is recorded per subscription in Firestore when configured.

## App Store transaction grant
- `POST /token` with `grantType: "urn:app:grant:appstore-transaction-jws"` accepts a signed transaction JWS from StoreKit, verifies it with Apple's App Store Server API, records usage for the subscription, and issues a JWT access token tied to the transaction.

Send the original transaction identifier for subscriptions so renewal activity collapses to a single usage record on the server.

Provide at least one Apple root certificate via `APPLE_ROOT_CERT_PATHS` or `APPLE_ROOT_CERT_BASE64` before calling the verification endpoint; the server needs it to validate Apple's certificate chain. The endpoint returns `403` for expired subscriptions and `503` when Apple is unavailable so the client can retry.

Forward the returned `access_token` when calling Mechanical Muse endpoints to unlock the Mechanical Muse features for that user.

## Running quality checks
```bash
uv run --extra dev ruff check
uv run --extra dev ruff format --check
uv run --extra dev mypy .
uv run --extra dev pytest
```

## Running tests
Add additional tests under `tests/`. Auth-specific cases live in `test_auth.py`; Mechanical Muse coverage is in `test_mech_muse.py`.

## Docker
Build and run the container locally:
```bash
docker build -t construct-server .
docker run --rm -p 8080:8080 \
  -e ADMIN_PASSWORD=your-prod-password \
  -e JWT_SECRET=super-secret \
  -e OPENAI_API_KEY=sk-prod-key \
  construct-server
```

## Deploying to Cloud Run
1. Build and push the container image:
   ```bash
   PROJECT_ID="your-gcp-project"
   IMAGE="gcr.io/${PROJECT_ID}/construct-server"
   gcloud builds submit --tag "${IMAGE}"
   ```
2. Deploy to Cloud Run:
   ```bash
   gcloud run deploy construct-server \
     --image "${IMAGE}" \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --set-env-vars ADMIN_PASSWORD=your-prod-password,JWT_SECRET=super-secret,OPENAI_API_KEY=sk-prod-key
   ```
3. Open the service URL printed by the deploy command.

Adjust the region, service name, and authentication flags as needed for your environment.

## Terraform infrastructure
Terraform configuration lives in `infra/` and can manage the Cloud Run service.

```bash
cd infra
terraform init
terraform apply \
  -var="project_id=your-gcp-project" \
  -var="image=gcr.io/your-gcp-project/construct-server:latest" \
  -var='service_env_vars={"ADMIN_PASSWORD"="your-password","JWT_SECRET"="super-secret","OPENAI_API_KEY"="sk-prod-key"}'
```

The configuration enables the required Cloud Run APIs, deploys the service, sets any provided environment variables, and (optionally) allows unauthenticated access. Update the variables and inputs as your deployment pipeline evolves.

## OpenAPI schema & generated Swift package
Run the helper script whenever the API surface changes:

```bash
uv run --project Server python scripts/generate_openapi.py
```

The script updates `Sources/ConstructAPI/openapi.json`, which the `ConstructAPI` SwiftPM target feeds into Apple’s `swift-openapi-generator` plugin to produce strongly typed Swift models at build time.
