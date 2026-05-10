output "uami_client_id" {
  description = "UAMI client ID; annotate the otel-collector KSA with azure.workload.identity/client-id=<this>"
  value       = azurerm_user_assigned_identity.otel.client_id
}

output "uami_principal_id" {
  description = "UAMI principal ID (object ID)"
  value       = azurerm_user_assigned_identity.otel.principal_id
}
