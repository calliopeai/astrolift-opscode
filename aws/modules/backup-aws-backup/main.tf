data "aws_partition" "current" {}

# -----------------------------------------------------------------------------
# AWS Backup vault + plan + selections (RDS, EFS, DynamoDB)
# -----------------------------------------------------------------------------

resource "aws_backup_vault" "this" {
  name        = "${var.name}-vault"
  kms_key_arn = var.vault_kms_key_id

  tags = var.tags
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule_cron
    start_window      = 60
    completion_window = 360

    lifecycle {
      cold_storage_after = var.cold_storage_after_days
      delete_after       = var.delete_after_days
    }
  }

  tags = var.tags
}

# Service role AWS Backup uses to read source resources + write recovery points.
resource "aws_iam_role" "backup" {
  name_prefix = "${var.name}-aws-backup-"
  path        = "/astrolift/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# -----------------------------------------------------------------------------
# Resource selections per service. Each is created only if its arn list is
# non-empty so an unused service doesn't carry an empty selection.
# -----------------------------------------------------------------------------

resource "aws_backup_selection" "rds" {
  count = length(var.rds_arns) == 0 ? 0 : 1

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-rds"
  plan_id      = aws_backup_plan.this.id
  resources    = var.rds_arns
}

resource "aws_backup_selection" "efs" {
  count = length(var.efs_arns) == 0 ? 0 : 1

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-efs"
  plan_id      = aws_backup_plan.this.id
  resources    = var.efs_arns
}

resource "aws_backup_selection" "dynamodb" {
  count = length(var.dynamodb_arns) == 0 ? 0 : 1

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-dynamodb"
  plan_id      = aws_backup_plan.this.id
  resources    = var.dynamodb_arns
}
