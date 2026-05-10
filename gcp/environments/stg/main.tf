# -----------------------------------------------------------------------------
# Astrolift — GCP Staging Environment
#
# Mirrors dev topology with stg-tier sizing: regional HA Cloud SQL, multi-zone
# Memorystore Standard, per-zone Cloud NAT, longer backup retention, Velero
# enabled, GCS lifecycle on. Same shape as AWS stg.
# -----------------------------------------------------------------------------

terraform {
  backend "gcs" {
    # Bucket name + prefix injected at init time via -backend-config.
    # Default scheme: bucket = "tf-state-${PROJECT_ID}", prefix = "gcp/stg".
    # Run: ./run.sh init gcp stg
  }
}

locals {
  name         = "stg-astrolift"
  env          = "staging"
  region       = var.region
  project_id   = var.project_id
  service_name = "astrolift"
  owner        = "astrolift"
  domain       = var.base_domain
  vpc_cidr     = "10.50.0.0/16"

  labels = {
    service     = local.service_name
    environment = local.env
    owner       = local.owner
    managed-by  = "terraform"
  }
}
