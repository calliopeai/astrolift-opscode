# -----------------------------------------------------------------------------
# Observability stack
#
# Each module is gated by its enable_* toggle, and additionally requires
# enable_aks (cluster-bound modules need an AKS OIDC issuer for federated
# credentials). Workload Identity is required for all bindings; the
# enable_workload_identity toggle stays on by default.
# -----------------------------------------------------------------------------

module "fluent_bit" {
  count  = var.enable_aks && var.enable_fluent_bit ? 1 : 0
  source = "../../modules/observability-fluent-bit-loganalytics"

  name                       = local.name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = local.location
  tags                       = local.tags
  aks_oidc_issuer_url        = module.aks[0].oidc_issuer_url
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

module "managed_prom_grafana" {
  count  = var.enable_aks && var.enable_managed_prom_grafana ? 1 : 0
  source = "../../modules/observability-managed-prom-grafana"

  name                = local.name
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  tags                = local.tags
  admin_principal_ids = []
}

module "otel_azuremonitor" {
  count  = var.enable_aks && var.enable_otel_azuremonitor ? 1 : 0
  source = "../../modules/observability-otel-azuremonitor"

  name                = local.name
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  tags                = local.tags
  aks_oidc_issuer_url = module.aks[0].oidc_issuer_url
}
