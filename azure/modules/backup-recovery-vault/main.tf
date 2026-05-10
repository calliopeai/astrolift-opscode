resource "azurerm_recovery_services_vault" "main" {
  name                = "${var.name}-rsv"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.vault_sku

  soft_delete_enabled = var.soft_delete_enabled
  storage_mode_type   = var.storage_mode_type

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Default daily VM/disk backup policy; AKS-tier policies (preview) come
# in a follow-up when operators opt in.
resource "azurerm_backup_policy_vm" "default" {
  name                = "${var.name}-vm-policy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  policy_type = "V2"

  backup {
    frequency     = "Daily"
    time          = "02:00"
    hour_interval = 24
  }

  retention_daily {
    count = 30
  }
}
