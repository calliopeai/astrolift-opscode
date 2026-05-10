# -----------------------------------------------------------------------------
# Astrolift — GCP Production Environment
#
# Mirrors dev topology with prd-tier sizing: regional HA Cloud SQL with read
# replica, multi-zone Memorystore Standard, per-zone Cloud NAT, 30d backup
# retention, full observability + backup. Same shape as AWS prd.
# -----------------------------------------------------------------------------

terraform {
  backend "gcs" {
    # Bucket name + prefix injected at init time via -backend-config.
    # Default scheme: bucket = "tf-state-${PROJECT_ID}", prefix = "gcp/prd".
    # Run: ./run.sh init gcp prd
  }
}

locals {
  name         = "prd-astrolift"
  env          = "production"
  region       = var.region
  project_id   = var.project_id
  service_name = "astrolift"
  owner        = "astrolift"
  domain       = var.base_domain
  vpc_cidr     = "10.100.0.0/16"

  labels = {
    service     = local.service_name
    environment = local.env
    owner       = local.owner
    managed-by  = "terraform"
  }
}
