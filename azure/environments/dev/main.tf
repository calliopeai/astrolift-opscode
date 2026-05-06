# EXPERIMENTAL — In Progress
# Azure support is under active development. Not yet validated against
# a live Azure subscription. Contributions welcome.

# -----------------------------------------------------------------------------
# Astrolift — Azure Development Environment
# -----------------------------------------------------------------------------

terraform {
  # Backend configured via -backend-config at init time.
  # See azure/config.env for project/region settings.
  # Run: ./run.sh init azure dev

  # backend "azurerm" {
  #   resource_group_name  = "astrolift-tfstate-rg"
  #   storage_account_name = "astrolifttfstate"
  #   container_name       = "tfstate"
  #   key                  = "azure/dev/terraform.tfstate"
  # }
}

locals {
  name         = "dev-astrolift"
  env          = "development"
  location     = var.location
  service_name = "astrolift"
  owner        = "astrolift"
  ver          = "1.0"
  domain       = "dev.astrolift.net"
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
data "azurerm_subscription" "current" {}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "${local.name}-rg"
  location = local.location
  tags     = local.tags
}
