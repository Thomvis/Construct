# Terraform infrastructure

This directory contains a minimal Terraform configuration for managing the Construct Cloud Run service.

## Usage
1. Ensure the [Google Cloud SDK](https://cloud.google.com/sdk) is installed and authenticated against the target project.
2. Provide Terraform with your project ID, target region, the container image to deploy, and any required environment variables.

```bash
terraform init
terraform apply \
  -var="project_id=your-gcp-project" \
  -var="image=gcr.io/your-gcp-project/construct-server:latest" \
  -var='service_env_vars={"ADMIN_PASSWORD"="your-password","JWT_SECRET"="super-secret"}'
```

## Inputs
- `project_id` (required): Destination GCP project ID.
- `image` (required): Fully-qualified container image reference for the service.
- `region`: Deployment region (default `us-central1`).
- `service_name`: Cloud Run service name (default `construct-server`).
- `container_port`: Container listening port (default `8080`).
- `allow_unauthenticated`: Grant public access when `true` (default `true`).
- `service_env_vars`: Map of environment variables to inject into the Cloud Run revision (default `{}`).

The configuration enables required APIs (`run.googleapis.com`, `cloudbuild.googleapis.com`), provisions the Cloud Run service, and optionally configures public invocation permissions.
