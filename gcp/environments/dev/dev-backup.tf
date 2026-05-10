# -----------------------------------------------------------------------------
# Backup stack
#
# Velero handles cluster-side PV snapshots to GCS. Cloud SQL backups are
# configured inline on the instance (dev-cloudsql.tf) gated by
# enable_cloudsql_pitr.
# -----------------------------------------------------------------------------

module "velero" {
  count  = var.enable_gke && var.enable_velero ? 1 : 0
  source = "../../modules/backup-velero-gcp"

  name               = local.name
  project_id         = local.project_id
  labels             = local.labels
  cluster_name       = var.enable_gke ? module.gke[0].cluster_name : ""
  wi_pool            = local.wi_pool
  backup_bucket_name = "${local.name}-velero-backups"
  create_bucket      = true
  retention_days     = 7
}
