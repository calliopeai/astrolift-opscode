# -----------------------------------------------------------------------------
# Virtual Network + Subnets + NAT Gateway (staging)
#
# Subnets are sized off local.vnet_cidr (10.50.0.0/16). NAT topology is
# per-zone in stg/prd: each AZ gets its own NAT Gateway + public IP, so a
# zone outage doesn't lose egress for surviving zones.
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "${local.name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.vnet_cidr]

  tags = merge(local.tags, {
    Name = "${local.name}-vnet"
  })
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "azurerm_subnet" "app" {
  name                 = "${local.name}-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.50.1.0/24"]

  service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

resource "azurerm_subnet" "database" {
  name                 = "${local.name}-database"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.50.11.0/24"]

  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "cache" {
  name                 = "${local.name}-cache"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.50.21.0/24"]
}

resource "azurerm_subnet" "container_apps" {
  name                 = "${local.name}-container-apps"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.50.32.0/23"]

  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway (per-zone for stg — survives single-zone outage)
# -----------------------------------------------------------------------------

locals {
  nat_zones = ["1", "2", "3"]
}

resource "azurerm_public_ip" "nat" {
  for_each = toset(local.nat_zones)

  name                = "${local.name}-nat-ip-z${each.value}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [each.value]

  tags = merge(local.tags, {
    Name = "${local.name}-nat-ip-z${each.value}"
    Zone = each.value
  })
}

resource "azurerm_nat_gateway" "main" {
  for_each = toset(local.nat_zones)

  name                = "${local.name}-nat-z${each.value}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
  zones               = [each.value]

  tags = merge(local.tags, {
    Name = "${local.name}-nat-z${each.value}"
    Zone = each.value
  })
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  for_each = toset(local.nat_zones)

  nat_gateway_id       = azurerm_nat_gateway.main[each.value].id
  public_ip_address_id = azurerm_public_ip.nat[each.value].id
}

# Subnet associations bind to zone "1" gateway by default. Zonal subnets
# in Azure are deployment-time bindings on the workloads, not the subnet
# itself, so the subnet-level NAT association points to one gateway —
# Azure routes traffic per-AZ within the gateway's zonal IP set when the
# subnet spans zones.
resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.main["1"].id
}

resource "azurerm_subnet_nat_gateway_association" "container_apps" {
  subnet_id      = azurerm_subnet.container_apps.id
  nat_gateway_id = azurerm_nat_gateway.main["1"].id
}

# -----------------------------------------------------------------------------
# Network Security Groups
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "app" {
  name                = "${local.name}-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-app-nsg"
  })
}

resource "azurerm_network_security_group" "database" {
  name                = "${local.name}-database-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowPostgreSQLFromVNet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-database-nsg"
  })
}

resource "azurerm_network_security_group" "cache" {
  name                = "${local.name}-cache-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowRedisFromVNet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-cache-nsg"
  })
}

# NSG Associations
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_subnet_network_security_group_association" "cache" {
  subnet_id                 = azurerm_subnet.cache.id
  network_security_group_id = azurerm_network_security_group.cache.id
}
