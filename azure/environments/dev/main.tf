# -----------------------------------------------------------------------------
# Astrolift — Azure Development Environment
# -----------------------------------------------------------------------------

terraform {
  backend "azurerm" {
    # resource_group_name + storage_account_name + container_name + key
    # injected at init time via -backend-config.
    # Default scheme: rg = "astrolift-tfstate-rg",
    #                 storage = "astrolifttfstate",
    #                 container = "tfstate",
    #                 key = "azure/dev/terraform.tfstate".
    # Run: ./run.sh init azure dev
  }
}

locals {
  name         = "dev-astrolift"
  env          = "development"
  location     = var.location
  service_name = "astrolift"
  owner        = "astrolift"
  domain       = var.base_domain
  vnet_cidr    = "10.0.0.0/16"

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
