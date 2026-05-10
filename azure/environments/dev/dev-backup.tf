# -----------------------------------------------------------------------------
# Backup stack
#
# Velero handles cluster-side PV snapshots to a Storage Account container.
# Recovery Services Vault holds disk + AKS (preview) backup policies.
# Postgres backups are configured inline on the instance (dev-postgres.tf,
# geo_redundant gated by enable_postgres_geo_backup).
# -----------------------------------------------------------------------------

module "velero" {
  count  = var.enable_aks && var.enable_velero ? 1 : 0
  source = "../../modules/backup-velero-azure"

  name                 = local.name
  resource_group_name  = azurerm_resource_group.main.name
  location             = local.location
  tags                 = local.tags
  aks_oidc_issuer_url  = module.aks[0].oidc_issuer_url
  subscription_id      = data.azurerm_client_config.current.subscription_id
  storage_account_name = "${replace(local.name, "-", "")}velbk"
  container_name       = "velero"
  create_storage       = true
  retention_days       = 7
}

module "recovery_vault" {
  count  = var.enable_azure_backup_vault ? 1 : 0
  source = "../../modules/backup-recovery-vault"

  name                = local.name
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  tags                = local.tags
  storage_mode_type   = "LocallyRedundant"
}
