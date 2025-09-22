# Construct Server

A minimal FastAPI service managed with [uv](https://github.com/astral-sh/uv) and ready for deployment to Google Cloud Run.

## Prerequisites
- Python 3.11+ (managed via `uv`)
- [uv CLI](https://github.com/astral-sh/uv) installed locally
- [Docker](https://www.docker.com/) for container builds
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated to your GCP project for deployment

## Configuration
Environment variables configure authentication and OpenAI access:
- `ADMIN_PASSWORD`: Magic password that issues an admin JWT (default `change-me`).
- `JWT_SECRET`: Symmetric signing key for JWTs (default `change-me-too`).
- `ACCESS_TOKEN_EXPIRE_MINUTES`: Lifetime for issued tokens (default `60`).
- `OPENAI_API_KEY`: API key used for Mechanical Muse requests (**required** for Mech Muse endpoints).
- `OPENAI_MODEL`: OpenAI Responses model to use (default `gpt-4.1-mini`).
- `OPENAI_TEMPERATURE`: Sampling temperature when talking to OpenAI (default `0.7`).
- `OPENAI_TIMEOUT_SECONDS`: HTTP timeout when calling OpenAI (default `180`).
- `OPENAI_MAX_OUTPUT_TOKENS`: Optional cap on OpenAI completion tokens.

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
The Mechanical Muse API is grouped under `/mech-muse`.

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
The response returns a simplified stat block matching the supplied schema. Provide `OPENAI_API_KEY` (and optionally `OPENAI_MODEL`, etc.) before calling the endpoint.

## Running quality checks
```bash
uv run --extra dev ruff check
uv run --extra dev ruff format --check
uv run --extra dev mypy .
uv run --extra dev pytest
```

## Running tests
Add additional tests under `tests/`. Example tests cover the authentication flow, Mechanical Muse integration, and public endpoints using FastAPI's `TestClient`.

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
