# -----------------------------------------------------------------------------
# Cloud Storage — File Storage Bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "access_logs" {
  name                        = "${local.name}-access-logs-${local.project_id}"
  location                    = local.region
  project                     = local.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(local.labels, {
    purpose = "gcs-access-logs"
  })
}

resource "google_storage_bucket" "files" {
  name     = "${local.name}-files-${local.project_id}"
  location = local.region
  project  = local.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  logging {
    log_bucket        = google_storage_bucket.access_logs.name
    log_object_prefix = "files/"
  }

  cors {
    origin          = ["https://${local.domain}", "https://*.${local.domain}"]
    method          = ["GET", "PUT", "POST"]
    response_header = ["Content-Type", "ETag"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # Coldline / Archive transitions for noncurrent versions (gated by
  # enable_gcs_lifecycle). Current versions are untouched — only old
  # generations get tiered down to cheaper storage classes.
  dynamic "lifecycle_rule" {
    for_each = var.enable_gcs_lifecycle ? [1] : []
    content {
      condition {
        age                = 30
        with_state         = "ARCHIVED"
        num_newer_versions = 1
      }
      action {
        type          = "SetStorageClass"
        storage_class = "COLDLINE"
      }
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.enable_gcs_lifecycle ? [1] : []
    content {
      condition {
        age                = 180
        with_state         = "ARCHIVED"
        num_newer_versions = 1
      }
      action {
        type          = "SetStorageClass"
        storage_class = "ARCHIVE"
      }
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.enable_gcs_lifecycle ? [1] : []
    content {
      condition {
        age                = 730
        with_state         = "ARCHIVED"
        num_newer_versions = 1
      }
      action {
        type = "Delete"
      }
    }
  }

  labels = merge(local.labels, {
    purpose = "application-file-storage"
  })
}
