resource "azurerm_monitor_workspace" "main" {
  name                = "${var.name}-amw"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_dashboard_grafana" "main" {
  name                              = "${var.name}-grafana"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = true

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.main.id
  }

  tags = var.tags
}

# Grant Grafana Admin to provided AAD principals.
resource "azurerm_role_assignment" "grafana_admin" {
  for_each = toset(var.admin_principal_ids)

  scope                = azurerm_dashboard_grafana.main.id
  role_definition_name = "Grafana Admin"
  principal_id         = each.value
}
