locals {
  oidc_issuer_url = replace(var.cluster_oidc_provider_arn, "/^(.*provider/)/", "")
}

resource "aws_iam_role" "otel_xray" {
  name_prefix = "${var.name}-otel-xray-"
  path        = "/astrolift/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.cluster_oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "otel_xray" {
  name = "${var.name}-otel-xray"
  role = aws_iam_role.otel_xray.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries",
        "ssm:GetParameters",
      ]
      Resource = "*"
    }]
  })
}
