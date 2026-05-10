resource "azurerm_storage_account" "backups" {
  count = var.create_storage ? 1 : 0

  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.retention_days
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "velero" {
  name                  = var.container_name
  storage_account_name  = var.storage_account_name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.backups]
}

resource "azurerm_user_assigned_identity" "velero" {
  name                = "${var.name}-velero"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "velero" {
  name                = "${var.name}-velero"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.velero.id
  subject             = "system:serviceaccount:velero:velero"
}

locals {
  storage_account_id = var.create_storage ? azurerm_storage_account.backups[0].id : "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
}

# Storage Blob Data Contributor on the backup container.
resource "azurerm_role_assignment" "velero_blob" {
  scope                = local.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}

# Disk Backup Reader for PV snapshot operations on managed disks.
resource "azurerm_role_assignment" "velero_disk_reader" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Disk Snapshot Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}
