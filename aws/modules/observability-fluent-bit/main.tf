data "aws_partition" "current" {}

locals {
  oidc_issuer_url = replace(var.cluster_oidc_provider_arn, "/^(.*provider/)/", "")
}

resource "aws_iam_role" "fluent_bit" {
  name_prefix = "${var.name}-fluent-bit-"
  path        = "/astrolift/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.cluster_oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:fluent-bit"
          "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "fluent_bit_cw_logs" {
  name = "${var.name}-fluent-bit-cw-logs"
  role = aws_iam_role.fluent_bit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
      ]
      Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:${var.log_group_name}:*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "pods" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(var.tags, {
    Name      = var.log_group_name
    Component = "fluent-bit"
  })
}
