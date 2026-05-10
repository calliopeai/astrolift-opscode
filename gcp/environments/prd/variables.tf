variable "region" {
  description = "GCP region for this environment (no default; set via gcp/config.env or -var)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "base_domain" {
  description = "Base DNS zone for this environment (e.g. acme.com or platform.acme.com). Operator must own this zone or have NS delegation to Cloud DNS."
  type        = string
}

# -----------------------------------------------------------------------------
# Production Environment Variables
# Override defaults via terraform.tfvars or -var flags.
# -----------------------------------------------------------------------------

# Container runtime selection — enable one or both
variable "enable_cloud_run" {
  description = "Enable Cloud Run container runtime"
  type        = bool
  default     = true
}

variable "enable_gke" {
  description = "Enable GKE Kubernetes container runtime"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Observability + backup toggles
#
# Defaults follow a dev=light / stg=most / prd=full ladder. Self-hosted
# operators flip these per cluster.
# -----------------------------------------------------------------------------

variable "enable_fluent_bit" {
  description = "Deploy Fluent Bit DaemonSet shipping pod logs to Cloud Logging"
  type        = bool
  default     = true
}

variable "enable_managed_prom" {
  description = "Provision GKE Managed Prometheus + Cloud Monitoring integration"
  type        = bool
  default     = true
}

variable "enable_otel_cloudtrace" {
  description = "Deploy OpenTelemetry collector with Cloud Trace exporter"
  type        = bool
  default     = true
}

variable "enable_velero" {
  description = "Install Velero with the gcp-pv-backup plugin for cluster snapshots to GCS"
  type        = bool
  default     = true
}

variable "enable_gcs_lifecycle" {
  description = "Apply Coldline / Archive transition lifecycle to GCS bucket noncurrent versions"
  type        = bool
  default     = true
}

# Cloud Run settings
variable "container_image" {
  description = "Docker image for the Cloud Run service (Artifact Registry URI)"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

# Database
variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-custom-4-15360"
}

variable "db_availability_type" {
  description = "Cloud SQL availability type — REGIONAL for multi-zone HA, ZONAL for single-zone"
  type        = string
  default     = "REGIONAL"
}

variable "db_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 250
}

variable "db_backup_retention_days" {
  description = "Cloud SQL retained automated backup count (one per day)"
  type        = number
  default     = 30
}

variable "db_read_replica_count" {
  description = "Number of Cloud SQL read replicas (replicas inherit tier from primary unless overridden)"
  type        = number
  default     = 1
}

# Cache
variable "redis_memory_size_gb" {
  description = "Memorystore Redis memory size in GB"
  type        = number
  default     = 8
}

variable "redis_tier" {
  description = "Memorystore tier — BASIC (single node) or STANDARD_HA (multi-zone replicated)"
  type        = string
  default     = "STANDARD_HA"
}
