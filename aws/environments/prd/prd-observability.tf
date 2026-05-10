# -----------------------------------------------------------------------------
# Observability stack
#
# Each module is gated by its enable_* toggle in variables.tf, and additionally
# requires enable_eks = true (cluster-bound modules deploy into EKS).
# -----------------------------------------------------------------------------

module "fluent_bit" {
  count  = var.enable_eks && var.enable_fluent_bit ? 1 : 0
  source = "../../modules/observability-fluent-bit"

  name                      = local.name
  tags                      = local.tags
  cluster_name              = module.eks[0].cluster_name
  cluster_oidc_provider_arn = module.eks[0].oidc_provider_arn
  log_group_name            = "/aws/eks/${local.name}/pods"
  log_retention_days        = 30
}

module "amp" {
  count  = var.enable_eks && var.enable_amp_amg ? 1 : 0
  source = "../../modules/observability-amp"

  name                      = local.name
  tags                      = local.tags
  region                    = local.region
  cluster_name              = module.eks[0].cluster_name
  cluster_oidc_provider_arn = module.eks[0].oidc_provider_arn
}

module "amg" {
  count  = var.enable_eks && var.enable_amp_amg ? 1 : 0
  source = "../../modules/observability-amg"

  name                         = local.name
  tags                         = local.tags
  amp_workspace_id             = module.amp[0].workspace_id
  amp_workspace_query_endpoint = module.amp[0].query_endpoint
  authentication_provider      = "AWS_SSO"
  admin_user_arns              = []
}

module "otel_xray" {
  count  = var.enable_eks && var.enable_otel_xray ? 1 : 0
  source = "../../modules/observability-otel-xray"

  name                      = local.name
  tags                      = local.tags
  cluster_name              = module.eks[0].cluster_name
  cluster_oidc_provider_arn = module.eks[0].oidc_provider_arn
  namespace                 = "observability"
  service_account_name      = "otel-collector"
}
