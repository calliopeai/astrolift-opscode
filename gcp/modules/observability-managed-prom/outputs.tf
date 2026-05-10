output "gsa_email" {
  description = "Google Service Account email for the in-cluster Prometheus collector"
  value       = google_service_account.managed_prom.email
}

output "ksa_annotation" {
  description = "Annotation to apply to the prometheus KSA"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.managed_prom.email}"
}
