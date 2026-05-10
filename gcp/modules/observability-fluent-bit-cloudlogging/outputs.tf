output "gsa_email" {
  description = "Google Service Account email; annotate the fluent-bit KSA with this"
  value       = google_service_account.fluent_bit.email
}

output "ksa_annotation" {
  description = "Annotation to apply to the fluent-bit Kubernetes ServiceAccount"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.fluent_bit.email}"
}
