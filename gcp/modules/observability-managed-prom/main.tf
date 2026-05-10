# GKE Managed Prometheus is enabled at the cluster level (see gke/main.tf
# monitoring_config.enable_components). This module provisions the GSA +
# Workload Identity binding for in-cluster collectors that need to write
# directly to Cloud Monitoring (e.g. an OTel collector with the
# googlecloud exporter, or a stand-alone PrometheusRule operator).

resource "google_service_account" "managed_prom" {
  project      = var.project_id
  account_id   = substr("${var.name}-prom", 0, 30)
  display_name = "Astrolift Managed Prometheus collector"
}

resource "google_project_iam_member" "managed_prom_metric" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.managed_prom.email}"
}

resource "google_project_iam_member" "managed_prom_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.managed_prom.email}"
}

# Bind any KSA in the observability namespace; collectors can run under
# different SAs (kube-prometheus-stack uses prometheus-operator,
# OTel uses otel-collector) so we widen via wildcard subjects.
resource "google_service_account_iam_member" "managed_prom_wi" {
  service_account_id = google_service_account.managed_prom.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.wi_pool}[${var.namespace}/prometheus]"
}
