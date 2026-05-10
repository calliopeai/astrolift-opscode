# -----------------------------------------------------------------------------
# Artifact Registry repositories
#
# Repos for the Astrolift control-plane images (api, ui, worker, status).
# Tenant per-app repos are created at runtime by the GCP provider plugin
# under astrolift/<org>/<app>/<workload>; those are NOT provisioned here.
# -----------------------------------------------------------------------------

locals {
  platform_ar_repos = ["api", "ui", "worker", "status"]
}

resource "google_artifact_registry_repository" "platform" {
  for_each = toset(local.platform_ar_repos)

  project       = local.project_id
  location      = local.region
  repository_id = "astrolift-${each.value}"
  format        = "DOCKER"
  description   = "Astrolift control-plane image repo for ${each.value}"

  cleanup_policies {
    id     = "expire-untagged-30d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }

  cleanup_policies {
    id     = "keep-latest-30-tagged"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  labels = local.labels

  depends_on = [google_project_service.required]
}
