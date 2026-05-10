# -----------------------------------------------------------------------------
# Astrolift — Azure Staging Environment
# -----------------------------------------------------------------------------

terraform {
  backend "azurerm" {
    # resource_group_name + storage_account_name + container_name + key
    # injected at init time via -backend-config.
    # Default scheme: rg = "astrolift-tfstate-rg",
    #                 storage = "astrolifttfstate",
    #                 container = "tfstate",
    #                 key = "azure/stg/terraform.tfstate".
    # Run: ./run.sh init azure stg
  }
}

locals {
  name         = "stg-astrolift"
  env          = "staging"
  location     = var.location
  service_name = "astrolift"
  owner        = "astrolift"
  domain       = var.base_domain
  vnet_cidr    = "10.50.0.0/16"

  tags = {
    Name        = local.name
    Service     = local.service_name
    Owner       = local.owner
    Environment = local.env
    ManagedBy   = "terraform"
  }
}

data "azurerm_client_config" "current" {}
# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "${local.name}-rg"
  location = local.location
  tags     = local.tags
}
