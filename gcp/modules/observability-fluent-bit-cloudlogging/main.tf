resource "google_service_account" "fluent_bit" {
  project      = var.project_id
  account_id   = substr("${var.name}-fb", 0, 30)
  display_name = "Astrolift Fluent Bit (Cloud Logging writer)"
}

resource "google_project_iam_member" "fluent_bit_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.fluent_bit.email}"
}

resource "google_project_iam_member" "fluent_bit_metric" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.fluent_bit.email}"
}

# Workload Identity binding: the in-cluster fluent-bit SA assumes this GSA.
resource "google_service_account_iam_member" "fluent_bit_wi" {
  service_account_id = google_service_account.fluent_bit.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.wi_pool}[${var.namespace}/${var.service_account_name}]"
}
