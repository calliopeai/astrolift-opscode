# -----------------------------------------------------------------------------
# Azure Container Registry
#
# Single registry hosts the Astrolift control-plane images at paths
# astrolift/{api,ui,worker,status}. Tenant images are pushed at runtime
# under astrolift/<org>/<app>/<workload>; ACR doesn't need per-repo
# resource declarations like ECR — paths are implicit on push.
# -----------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  # Name must be globally unique, alphanumeric, 5-50 chars. Strip dashes.
  name                = replace("${local.name}acr", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  sku                 = "Standard"
  admin_enabled       = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags

  depends_on = [azurerm_resource_provider_registration.required]
}
