resource "aws_grafana_workspace" "this" {
  name                     = "${var.name}-amg"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = [var.authentication_provider]
  permission_type          = "SERVICE_MANAGED"

  data_sources = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]

  tags = var.tags
}

resource "aws_grafana_role_association" "admins" {
  count = length(var.admin_user_arns) == 0 ? 0 : 1

  role         = "ADMIN"
  user_ids     = var.admin_user_arns
  workspace_id = aws_grafana_workspace.this.id
}
