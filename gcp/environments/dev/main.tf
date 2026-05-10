# -----------------------------------------------------------------------------
# Astrolift — GCP Development Environment
# -----------------------------------------------------------------------------

terraform {
  backend "gcs" {
    # Bucket name + prefix injected at init time via -backend-config.
    # Default scheme: bucket = "tf-state-${PROJECT_ID}", prefix = "gcp/dev".
    # Run: ./run.sh init gcp dev
  }
}

locals {
  name         = "dev-astrolift"
  env          = "development"
  region       = var.region
  project_id   = var.project_id
  service_name = "astrolift"
  owner        = "astrolift"
  domain       = "dev.astrolift.net"

  labels = {
    service     = local.service_name
    environment = local.env
    owner       = local.owner
    managed-by  = "terraform"
  }
}

