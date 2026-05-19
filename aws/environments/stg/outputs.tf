# -----------------------------------------------------------------------------
# Env-root outputs — consumed by aws/scripts/build-env.sh to produce the
# aws/outputs/<env>.env file that Helm + cold-boot.sh + astro CLI read.
# -----------------------------------------------------------------------------

output "aws_region" {
  description = "AWS region for this environment"
  value       = local.region
}

output "aws_account_id" {
  description = "AWS account ID hosting this environment"
  value       = data.aws_caller_identity.current.account_id
}

output "environment" {
  description = "Environment name (dev/stg/prd)"
  value       = local.env
}

output "base_domain" {
  description = "Operator-supplied base DNS zone for this environment"
  value       = local.domain
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

# Cluster (EKS — gated)
output "eks_cluster_name" {
  description = "EKS cluster name (empty if enable_eks = false)"
  value       = var.enable_eks ? module.eks[0].cluster_name : ""
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = var.enable_eks ? module.eks[0].cluster_endpoint : ""
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN (used to mint per-app IRSA roles)"
  value       = var.enable_eks ? module.eks[0].oidc_provider_arn : ""
}

# Datastores
output "rds_endpoint" {
  description = "RDS Postgres endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

# Object storage
output "s3_artifacts_bucket" {
  description = "S3 artifacts bucket name"
  value       = aws_s3_bucket.files.id
}

output "s3_artifacts_bucket_arn" {
  description = "S3 artifacts bucket ARN"
  value       = aws_s3_bucket.files.arn
}

# Container registry
output "ecr_registry" {
  description = "ECR registry hostname (account-scoped)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com"
}

# Secrets
output "secrets_manager_prefix" {
  description = "Secret Manager prefix for tenant + platform secrets"
  value       = "/astrolift"
}

output "db_credentials_arn" {
  description = "Secret Manager secret ARN for DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

# IAM (IRSA path the AWS provider plugin assumes)
output "irsa_role_path" {
  description = "IAM path under which provider-plugin-created IRSA roles live"
  value       = "/astrolift/"
}

# Email events pipeline (gated by enable_email_events)
output "ses_events_sns_topic_arn" {
  description = "SNS topic ARN for SES email events. Set as ASTROLIFT_SES_EVENTS_SNS_TOPIC_ARN (empty if enable_email_events = false)"
  value       = var.enable_email_events ? module.email_events[0].sns_topic_arn : ""
}
