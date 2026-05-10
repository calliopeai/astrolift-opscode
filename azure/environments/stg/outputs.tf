# -----------------------------------------------------------------------------
# Env-root outputs — symmetric with aws/environments/<env>/outputs.tf so a
# build-env.sh equivalent can render the azure/outputs/<env>.env file that
# Helm + cold-boot.sh + astro CLI consume.
# -----------------------------------------------------------------------------

output "azure_location" {
  description = "Azure region for this environment"
  value       = local.location
}

output "subscription_id" {
  description = "Azure subscription ID hosting this environment"
  value       = data.azurerm_client_config.current.subscription_id
}

output "tenant_id" {
  description = "Azure AD tenant ID for this subscription"
  value       = data.azurerm_client_config.current.tenant_id
}

output "environment" {
  description = "Environment name (development/staging/production)"
  value       = local.env
}

output "base_domain" {
  description = "Operator-supplied base DNS zone for this environment"
  value       = local.domain
}

output "resource_group_name" {
  description = "Resource Group hosting all environment resources"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

# Cluster (AKS — gated)
output "aks_cluster_name" {
  description = "AKS cluster name (empty if enable_aks = false)"
  value       = var.enable_aks ? module.aks[0].cluster_name : ""
}

output "aks_cluster_id" {
  description = "AKS cluster resource ID (empty if enable_aks = false)"
  value       = var.enable_aks ? module.aks[0].cluster_id : ""
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL (used to mint federated credentials for Workload Identity)"
  value       = var.enable_aks ? module.aks[0].oidc_issuer_url : ""
}

# Datastores
output "postgres_fqdn" {
  description = "Postgres Flexible Server FQDN (private)"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_admin_login" {
  description = "Postgres administrator login name"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "redis_hostname" {
  description = "Azure Cache for Redis hostname"
  value       = azurerm_redis_cache.main.hostname
}

output "redis_port" {
  description = "Azure Cache for Redis SSL port"
  value       = azurerm_redis_cache.main.ssl_port
}

# Object storage
output "storage_account_name" {
  description = "Storage account hosting the artifacts container"
  value       = azurerm_storage_account.files.name
}

# Container registry
output "acr_login_server" {
  description = "ACR login server hostname"
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "ACR registry name"
  value       = azurerm_container_registry.main.name
}

# Secrets
output "key_vault_uri" {
  description = "Key Vault DNS URI for the platform-secrets vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Workload Identity (UAMI) — gated
output "platform_uami_client_id" {
  description = "Platform UAMI client ID (used as azure.workload.identity/client-id annotation)"
  value       = var.enable_workload_identity ? azurerm_user_assigned_identity.platform[0].client_id : ""
}

output "platform_uami_principal_id" {
  description = "Platform UAMI principal (object) ID"
  value       = var.enable_workload_identity ? azurerm_user_assigned_identity.platform[0].principal_id : ""
}
