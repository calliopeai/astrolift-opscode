# -----------------------------------------------------------------------------
# Backup stack
#
# Velero handles cluster-side PV snapshots to GCS. Cloud SQL backups are
# configured inline on the instance (prd-cloudsql.tf) gated by PITR + retention.
# -----------------------------------------------------------------------------

module "velero" {
  count  = var.enable_gke && var.enable_velero ? 1 : 0
  source = "../../modules/backup-velero-gcp"

  name               = local.name
  project_id         = local.project_id
  labels             = local.labels
  wi_pool            = local.wi_pool
  backup_bucket_name = "${local.name}-velero-backups"
  create_bucket      = true
  retention_days     = 30
}
