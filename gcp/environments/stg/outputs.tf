# -----------------------------------------------------------------------------
# Env-root outputs — consumed by gcp/scripts/build-env.sh to produce the
# gcp/outputs/<env>.env file that Helm + cold-boot.sh + astro CLI read.
# Mirrors the AWS env-root outputs surface for symmetry.
# -----------------------------------------------------------------------------

output "gcp_region" {
  description = "GCP region for this environment"
  value       = local.region
}

output "gcp_project_id" {
  description = "GCP project ID hosting this environment"
  value       = local.project_id
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
  description = "VPC self-link"
  value       = google_compute_network.vpc.id
}

# Cluster (GKE — gated)
output "gke_cluster_name" {
  description = "GKE cluster name (empty if enable_gke = false)"
  value       = var.enable_gke ? module.gke[0].cluster_name : ""
}

output "gke_cluster_endpoint" {
  description = "GKE API endpoint (empty if enable_gke = false)"
  value       = var.enable_gke ? module.gke[0].endpoint : ""
}

output "wi_pool" {
  description = "Workload Identity pool name (used to mint per-app GSAs)"
  value       = local.wi_pool
}

# Datastores
output "cloudsql_connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance)"
  value       = google_sql_database_instance.postgres.connection_name
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP address (reachable via VPC peering)"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "redis_host" {
  description = "Memorystore Redis host"
  value       = google_redis_instance.redis.host
}

output "redis_port" {
  description = "Memorystore Redis port"
  value       = google_redis_instance.redis.port
}

# Object storage
output "gcs_artifacts_bucket" {
  description = "GCS artifacts bucket name"
  value       = google_storage_bucket.files.name
}

# Container registry
output "artifact_registry" {
  description = "Artifact Registry hostname for the platform image repos"
  value       = "${local.region}-docker.pkg.dev/${local.project_id}/astrolift"
}

# Secrets
output "secrets_prefix" {
  description = "Secret Manager prefix for tenant + platform secrets"
  value       = "${local.name}-"
}
