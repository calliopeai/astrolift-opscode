resource "google_service_account" "otel" {
  project      = var.project_id
  account_id   = substr("${var.name}-otel", 0, 30)
  display_name = "Astrolift OTel collector (Cloud Trace + Monitoring writer)"
}

resource "google_project_iam_member" "otel_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.otel.email}"
}

resource "google_project_iam_member" "otel_metric" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.otel.email}"
}

resource "google_project_iam_member" "otel_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.otel.email}"
}

resource "google_service_account_iam_member" "otel_wi" {
  service_account_id = google_service_account.otel.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.wi_pool}[${var.namespace}/${var.service_account_name}]"
}
