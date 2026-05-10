# -----------------------------------------------------------------------------
# Platform User-Assigned Managed Identity
#
# UAMI bound to the Astrolift control-plane services on AKS via Workload
# Identity federated credentials. Tenant per-pod UAMIs are created at
# runtime by the Azure provider plugin under astrolift-<namespace>-<sa>
# (see astrolift-providers/azure/identity_federated.py).
# -----------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "platform" {
  count = var.enable_workload_identity ? 1 : 0

  name                = "${local.name}-platform"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location

  tags = local.tags

  depends_on = [azurerm_resource_provider_registration.required]
}

# Key Vault access for platform secrets.
resource "azurerm_role_assignment" "platform_kv_secrets" {
  count = var.enable_workload_identity ? 1 : 0

  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.platform[0].principal_id
}

# Storage account access for the artifacts bucket.
resource "azurerm_role_assignment" "platform_storage_blob" {
  count = var.enable_workload_identity ? 1 : 0

  scope                = azurerm_storage_account.files.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.platform[0].principal_id
}

# ACR pull access for control-plane images.
resource "azurerm_role_assignment" "platform_acr_pull" {
  count = var.enable_workload_identity ? 1 : 0

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.platform[0].principal_id
}
