locals {
  oidc_issuer_url = replace(var.cluster_oidc_provider_arn, "/^(.*provider/)/", "")
}

resource "aws_prometheus_workspace" "this" {
  alias = "${var.name}-amp"

  tags = var.tags
}

resource "aws_prometheus_alert_manager_definition" "this" {
  count = var.alert_manager_definition == null ? 0 : 1

  workspace_id = aws_prometheus_workspace.this.id
  definition   = var.alert_manager_definition
}

# IRSA role for the in-cluster Prometheus / OTel collector to remote-write
# scraped metrics into the AMP workspace.
resource "aws_iam_role" "amp_write" {
  name_prefix = "${var.name}-amp-write-"
  path        = "/astrolift/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.cluster_oidc_provider_arn }
      Condition = {
        StringEquals = {
          # Match either the Prom Operator default SA or an OTel collector SA.
          "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${local.oidc_issuer_url}:sub" = "system:serviceaccount:observability:*"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "amp_write" {
  name = "${var.name}-amp-write"
  role = aws_iam_role.amp_write.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "aps:RemoteWrite",
        "aps:GetSeries",
        "aps:GetLabels",
        "aps:GetMetricMetadata",
      ]
      Resource = aws_prometheus_workspace.this.arn
    }]
  })
}
