# -----------------------------------------------------------------------------
# Aurora Serverless v2 PostgreSQL 16 (production)
# -----------------------------------------------------------------------------

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${local.name}-db"

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned"
  engine_version = "16.4"

  database_name   = "astrolift"
  master_username = "astrolift"
  master_password = random_password.db_password.result

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  iam_database_authentication_enabled = true

  backup_retention_period      = 30
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot        = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-db-final-${formatdate("YYYYMMDD", timestamp())}"

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_capacity
    max_capacity = var.db_max_capacity
  }

  tags = merge(local.tags, {
    Name   = "${local.name}-db"
    Engine = "aurora-postgresql-16"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  count = 2

  identifier         = "${local.name}-db-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  ca_cert_identifier = "rds-ca-rsa2048-g1"

  auto_minor_version_upgrade      = true
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  tags = merge(local.tags, {
    Name = "${local.name}-db-${count.index + 1}"
  })
}

# Customer-managed KMS key for Aurora storage + performance insights encryption.
resource "aws_kms_key" "rds" {
  description             = "KMS key for ${local.name} Aurora cluster encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableIAMUserPermissions"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  name_prefix = "${local.name}-aurora-pg16-"
  family      = "aurora-postgresql16"
  description = "Aurora PostgreSQL 16 parameter group for ${local.name}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "60000"
  }

  # Force TLS on all client connections (CKV2_AWS_69).
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-aurora-pg16-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_password" "db_password" {
  length  = 32
  special = false
}
