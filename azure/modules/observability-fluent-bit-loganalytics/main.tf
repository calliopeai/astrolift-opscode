resource "azurerm_user_assigned_identity" "fluent_bit" {
  name                = "${var.name}-fluent-bit"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# Federated credential — binds the in-cluster fluent-bit ServiceAccount
# to this UAMI via the AKS OIDC issuer.
resource "azurerm_federated_identity_credential" "fluent_bit" {
  name                = "${var.name}-fluent-bit"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.fluent_bit.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

# Log Analytics Contributor on the workspace so fluent-bit can ingest logs.
resource "azurerm_role_assignment" "fluent_bit_la" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.fluent_bit.principal_id
}
