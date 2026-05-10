resource "google_storage_bucket" "backups" {
  count = var.create_bucket ? 1 : 0

  project       = var.project_id
  name          = var.backup_bucket_name
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

resource "google_service_account" "velero" {
  project      = var.project_id
  account_id   = substr("${var.name}-velero", 0, 30)
  display_name = "Astrolift Velero (cluster snapshot writer)"
}

# Bucket-scoped object admin so velero can write/read backup objects.
resource "google_storage_bucket_iam_member" "velero_object_admin" {
  bucket = var.backup_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.velero.email}"

  depends_on = [google_storage_bucket.backups]
}

# Compute permissions for PV snapshot create/delete.
resource "google_project_iam_member" "velero_compute" {
  project = var.project_id
  role    = "roles/compute.storageAdmin"
  member  = "serviceAccount:${google_service_account.velero.email}"
}

resource "google_service_account_iam_member" "velero_wi" {
  service_account_id = google_service_account.velero.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.wi_pool}[velero/velero]"
}
