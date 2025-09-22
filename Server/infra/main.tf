terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "cloud_run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build" {
  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_service" "construct" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      containers {
        image = var.image

        ports {
          container_port = var.container_port
        }

        dynamic "env" {
          for_each = var.service_env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.cloud_run,
    google_project_service.cloud_build,
  ]
}

resource "google_cloud_run_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  location = google_cloud_run_service.construct.location
  project  = var.project_id
  service  = google_cloud_run_service.construct.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
