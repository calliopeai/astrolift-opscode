# -----------------------------------------------------------------------------
# Project service enablement
#
# Per spec 24 §14: enable the APIs the platform + provider plugin need.
# Run before any resource that depends on these (Terraform usually orders
# correctly via implicit graph; explicit depends_on stays cheap insurance).
# -----------------------------------------------------------------------------

locals {
  required_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "dns.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project = local.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}
