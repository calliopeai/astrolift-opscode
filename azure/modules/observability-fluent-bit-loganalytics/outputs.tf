output "uami_client_id" {
  description = "UAMI client ID; annotate the fluent-bit KSA with azure.workload.identity/client-id=<this>"
  value       = azurerm_user_assigned_identity.fluent_bit.client_id
}

output "uami_principal_id" {
  description = "UAMI principal ID (object ID)"
  value       = azurerm_user_assigned_identity.fluent_bit.principal_id
}
