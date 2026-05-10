# -----------------------------------------------------------------------------
# Azure resource provider registration
#
# Per spec 25 §14: register the resource providers the platform + provider
# plugin need before downstream resources reference them. These calls are
# idempotent — most subscriptions already have these registered.
# -----------------------------------------------------------------------------

locals {
  required_providers_azure = [
    "Microsoft.Compute",
    "Microsoft.ContainerService",
    "Microsoft.ContainerRegistry",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.Cache",
    "Microsoft.Storage",
    "Microsoft.Network",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.AlertsManagement",
    "Microsoft.Authorization",
    "Microsoft.Monitor",
    "Microsoft.Dashboard",
    "Microsoft.RecoveryServices",
    "Microsoft.Resources",
  ]
}

resource "azurerm_resource_provider_registration" "required" {
  for_each = toset(local.required_providers_azure)

  name = each.value
}
