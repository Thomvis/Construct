variable "project_id" {
  description = "GCP project ID where the Cloud Run service will be managed"
  type        = string
}

variable "region" {
  description = "Region to deploy the Cloud Run service"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name for the Cloud Run service"
  type        = string
  default     = "construct-server"
}

variable "image" {
  description = "Container image to deploy (e.g. gcr.io/<project>/construct-server:tag)"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the application container"
  type        = number
  default     = 8080
}

variable "allow_unauthenticated" {
  description = "Whether to allow unauthenticated invocations"
  type        = bool
  default     = true
}

variable "service_env_vars" {
  description = "Environment variables to inject into the Cloud Run revision"
  type        = map(string)
  default     = {}
}
