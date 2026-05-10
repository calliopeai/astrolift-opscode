output "vault_id" {
  description = "Recovery Services Vault ID"
  value       = azurerm_recovery_services_vault.main.id
}

output "vault_name" {
  description = "Recovery Services Vault name"
  value       = azurerm_recovery_services_vault.main.name
}

output "default_policy_id" {
  description = "Default VM/disk backup policy ID"
  value       = azurerm_backup_policy_vm.default.id
}
