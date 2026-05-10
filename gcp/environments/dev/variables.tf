variable "region" {
  description = "GCP region for this environment (no default; set via gcp/config.env or -var)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

# -----------------------------------------------------------------------------
# Dev Environment Variables
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
# Optional components. Defaults follow a dev=light / stg=most / prd=full
# ladder. Self-hosted operators flip these per cluster.
# -----------------------------------------------------------------------------

variable "enable_fluent_bit" {
  description = "Deploy Fluent Bit DaemonSet shipping pod logs to Cloud Logging"
  type        = bool
  default     = true
}

variable "enable_in_cluster_prom" {
  description = "Run Prometheus + Grafana in-cluster (default observability stack)"
  type        = bool
  default     = true
}

variable "enable_managed_prom" {
  description = "Provision GKE Managed Prometheus + Cloud Monitoring integration"
  type        = bool
  default     = false
}

variable "enable_otel_cloudtrace" {
  description = "Deploy OpenTelemetry collector with Cloud Trace exporter"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Bind GKE Workload Identity for tenant pods (required for GKE)"
  type        = bool
  default     = true
}

variable "enable_velero" {
  description = "Install Velero with the gcp-pv-backup plugin for cluster snapshots to GCS"
  type        = bool
  default     = false
}

variable "enable_cloudsql_pitr" {
  description = "Enable point-in-time recovery on Cloud SQL"
  type        = bool
  default     = false
}

variable "enable_gcs_lifecycle" {
  description = "Apply Coldline / Archive transition lifecycle to GCS bucket noncurrent versions"
  type        = bool
  default     = false
}

variable "enable_cloud_logging_router" {
  description = "Provision a Cloud Logging sink + bucket for long-term log retention"
  type        = bool
  default     = false
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
  default     = "db-f1-micro"
}

# Cache
variable "redis_memory_size_gb" {
  description = "Memorystore Redis memory size in GB"
  type        = number
  default     = 1
}
