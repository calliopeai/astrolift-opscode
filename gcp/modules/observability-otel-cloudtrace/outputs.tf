output "gsa_email" {
  description = "Google Service Account email for the OTel collector"
  value       = google_service_account.otel.email
}

output "ksa_annotation" {
  description = "Annotation to apply to the otel-collector KSA"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.otel.email}"
}
