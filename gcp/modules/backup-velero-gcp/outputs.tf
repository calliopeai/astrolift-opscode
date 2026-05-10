output "backup_bucket_name" {
  description = "GCS bucket Velero ships PV snapshots to"
  value       = var.backup_bucket_name
}

output "gsa_email" {
  description = "Google Service Account email for Velero (annotate KSA)"
  value       = google_service_account.velero.email
}

output "ksa_annotation" {
  description = "Annotation to apply to the velero Kubernetes ServiceAccount"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.velero.email}"
}
