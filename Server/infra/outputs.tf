output "service_url" {
  description = "Public URL of the Cloud Run service"
  value       = google_cloud_run_service.construct.status[0].url
}
