# -----------------------------------------------------------------------------
# Observability stack
#
# Each module is gated by its enable_* toggle, and additionally requires
# enable_gke = true (cluster-bound modules only meaningful with a cluster).
# Workload Identity is required for all GCP observability bindings; the
# enable_workload_identity toggle stays on by default.
# -----------------------------------------------------------------------------

locals {
  wi_pool = "${local.project_id}.svc.id.goog"
}

module "fluent_bit" {
  count  = var.enable_gke && var.enable_fluent_bit ? 1 : 0
  source = "../../modules/observability-fluent-bit-cloudlogging"

  name         = local.name
  project_id   = local.project_id
  labels       = local.labels
  cluster_name = var.enable_gke ? module.gke[0].cluster_name : ""
  wi_pool      = local.wi_pool
}

module "managed_prom" {
  count  = var.enable_gke && var.enable_managed_prom ? 1 : 0
  source = "../../modules/observability-managed-prom"

  name         = local.name
  project_id   = local.project_id
  labels       = local.labels
  cluster_name = var.enable_gke ? module.gke[0].cluster_name : ""
  wi_pool      = local.wi_pool
}

module "otel_cloudtrace" {
  count  = var.enable_gke && var.enable_otel_cloudtrace ? 1 : 0
  source = "../../modules/observability-otel-cloudtrace"

  name                 = local.name
  project_id           = local.project_id
  labels               = local.labels
  cluster_name         = var.enable_gke ? module.gke[0].cluster_name : ""
  wi_pool              = local.wi_pool
  namespace            = "observability"
  service_account_name = "otel-collector"
}
