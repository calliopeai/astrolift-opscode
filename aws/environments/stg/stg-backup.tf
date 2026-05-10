# -----------------------------------------------------------------------------
# Backup stack
#
# Velero handles cluster-side PV snapshots; AWS Backup handles managed
# data services (RDS, EFS, DynamoDB).
# -----------------------------------------------------------------------------

module "velero" {
  count  = var.enable_eks && var.enable_velero ? 1 : 0
  source = "../../modules/backup-velero"

  name                      = local.name
  tags                      = local.tags
  cluster_oidc_provider_arn = module.eks[0].oidc_provider_arn
  backup_bucket_name        = "${local.name}-velero-backups"
  create_bucket             = true
  retention_days            = 14
}

module "aws_backup" {
  count  = var.enable_aws_backup ? 1 : 0
  source = "../../modules/backup-aws-backup"

  name = local.name
  tags = local.tags

  rds_arns      = [aws_db_instance.postgres.arn]
  efs_arns      = var.enable_eks ? [module.eks[0].efs_arn] : []
  dynamodb_arns = []

  delete_after_days = 14
}
