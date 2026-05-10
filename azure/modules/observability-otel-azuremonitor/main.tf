resource "azurerm_user_assigned_identity" "otel" {
  name                = "${var.name}-otel"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "otel" {
  name                = "${var.name}-otel"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.otel.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Resource-group-scoped Monitoring Metrics Publisher for sending custom
# metrics into Azure Monitor.
resource "azurerm_role_assignment" "otel_metrics_publisher" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.otel.principal_id
}

# If an Application Insights component is provided, grant the OTel UAMI
# direct write access (used when shipping APM traces / spans).
resource "azurerm_role_assignment" "otel_ai_contributor" {
  count = var.application_insights_id == null ? 0 : 1

  scope                = var.application_insights_id
  role_definition_name = "Application Insights Component Contributor"
  principal_id         = azurerm_user_assigned_identity.otel.principal_id
}
