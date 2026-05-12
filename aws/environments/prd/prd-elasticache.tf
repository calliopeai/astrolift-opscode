# -----------------------------------------------------------------------------
# ElastiCache Redis 7 (production — multi-AZ replicas)
# -----------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name}-redis"
  description          = "Redis cluster for ${local.name}"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_clusters   = 3
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  subnet_group_name  = aws_elasticache_subnet_group.cache.name
  security_group_ids = [aws_security_group.redis.id]

  automatic_failover_enabled = true
  multi_az_enabled           = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auto_minor_version_upgrade = true
  kms_key_id                 = aws_kms_key.redis.arn

  snapshot_retention_limit = 7
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "mon:06:00-mon:07:00"

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(local.tags, {
    Name   = "${local.name}-redis"
    Engine = "redis-7"
  })
}

# Customer-managed KMS key for Redis at-rest encryption.
resource "aws_kms_key" "redis" {
  description             = "KMS key for ${local.name} ElastiCache encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableIAMUserPermissions"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name}-redis-kms"
  })
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${local.name}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${local.name}/slow-log"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.redis.arn

  tags = merge(local.tags, {
    Name = "/aws/elasticache/${local.name}/slow-log"
  })
}

resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = "/aws/elasticache/${local.name}/engine-log"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.redis.arn

  tags = merge(local.tags, {
    Name = "/aws/elasticache/${local.name}/engine-log"
  })
}

resource "aws_elasticache_parameter_group" "redis" {
  name        = "${local.name}-redis7"
  family      = "redis7"
  description = "Redis 7 parameter group for ${local.name}"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-redis7-params"
  })
}
