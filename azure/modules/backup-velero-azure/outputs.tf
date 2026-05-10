output "storage_account_name" {
  description = "Storage account name Velero ships PV snapshots to"
  value       = var.storage_account_name
}

output "container_name" {
  description = "Blob container name within the storage account"
  value       = azurerm_storage_container.velero.name
}

output "uami_client_id" {
  description = "UAMI client ID for Velero — annotate the velero KSA with azure.workload.identity/client-id=<this>"
  value       = azurerm_user_assigned_identity.velero.client_id
}

output "uami_principal_id" {
  description = "UAMI principal ID (object ID)"
  value       = azurerm_user_assigned_identity.velero.principal_id
}
