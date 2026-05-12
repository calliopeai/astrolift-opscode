# -----------------------------------------------------------------------------
# KMS keyring + crypto keys for envelope encryption
#
# - app: encrypts Secret Manager secrets + GCS bucket data
# - db:  encrypts Cloud SQL data at rest (set as kms_key_name on the
#        instance once enabled per cluster)
# Tenant-managed keys come from the per-tenant key namespace at runtime.
# -----------------------------------------------------------------------------

resource "google_kms_key_ring" "main" {
  project  = local.project_id
  name     = "${local.name}-keyring"
  location = local.region

  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key" "app" {
  name            = "${local.name}-app"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s" # 90 days

  labels = local.labels

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "db" {
  name            = "${local.name}-db"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s" # 90 days

  labels = local.labels

  lifecycle {
    prevent_destroy = true
  }
}
