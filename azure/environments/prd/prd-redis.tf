# -----------------------------------------------------------------------------
# Azure Cache for Redis (Premium P1 clustered for production)
#
# Premium tier enables clustering (sharding across shards) and
# zone-redundancy. shard_count = 2 gives us a clustered topology;
# adjust capacity for vertical scale per shard.
# -----------------------------------------------------------------------------

resource "azurerm_redis_cache" "main" {
  name                = "${local.name}-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  shard_count = 2

  redis_configuration {
    maxmemory_policy = "volatile-lru"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-redis"
  })
}
