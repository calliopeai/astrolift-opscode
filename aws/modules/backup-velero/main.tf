data "aws_partition" "current" {}

locals {
  oidc_issuer_url = replace(var.cluster_oidc_provider_arn, "/^(.*provider/)/", "")
  bucket_arn      = "arn:${data.aws_partition.current.partition}:s3:::${var.backup_bucket_name}"
}

# -----------------------------------------------------------------------------
# Backup S3 bucket (created when create_bucket = true)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  count = var.create_bucket ? 1 : 0

  bucket = var.backup_bucket_name

  tags = merge(var.tags, {
    Name      = var.backup_bucket_name
    Component = "velero"
  })
}

resource "aws_s3_bucket_versioning" "backups" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  rule {
    id     = "expire-after-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }
}

# -----------------------------------------------------------------------------
# Velero IRSA role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "velero" {
  name_prefix = "${var.name}-velero-"
  path        = "/astrolift/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.cluster_oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_url}:sub" = "system:serviceaccount:velero:velero"
          "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "velero" {
  name = "${var.name}-velero"
  role = aws_iam_role.velero.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "${local.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = local.bucket_arn
      },
    ]
  })
}
