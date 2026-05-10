variable "location" {
  description = "Azure region for this environment (no default; set via azure/config.env or -var)"
  type        = string
}

variable "base_domain" {
  description = "Base DNS zone for this environment (e.g. stg.acme.com). Operator must own this zone or have NS delegation to Azure DNS."
  type        = string
}

# -----------------------------------------------------------------------------
# Staging Environment Variables
# Override defaults via terraform.tfvars or -var flags.
# -----------------------------------------------------------------------------

# Container runtime selection — enable one or both
variable "enable_container_apps" {
  description = "Enable Azure Container Apps runtime"
  type        = bool
  default     = true
}

variable "enable_aks" {
  description = "Enable AKS Kubernetes container runtime"
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
  description = "Deploy Fluent Bit DaemonSet shipping pod logs to Log Analytics"
  type        = bool
  default     = true
}

variable "enable_managed_prom_grafana" {
  description = "Provision Azure Monitor Managed Prometheus + Managed Grafana"
  type        = bool
  default     = false
}

variable "enable_otel_azuremonitor" {
  description = "Deploy OpenTelemetry collector with Azure Monitor exporter"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Use Azure Workload Identity Federation for tenant pod identity (required for AKS)"
  type        = bool
  default     = true
}

variable "enable_velero" {
  description = "Install Velero with the azure-pv-backup add-on for cluster snapshots to Storage"
  type        = bool
  default     = true
}

variable "enable_postgres_geo_backup" {
  description = "Enable geo-redundant backups (GRS) on Postgres Flexible Server (in addition to default LRS)"
  type        = bool
  default     = false
}

variable "enable_blob_lifecycle" {
  description = "Apply Cool / Archive lifecycle to Storage account blob versions"
  type        = bool
  default     = true
}

variable "enable_azure_backup_vault" {
  description = "Provision a Recovery Services Vault + Azure Backup for AKS / Disks (preview)"
  type        = bool
  default     = true
}

# Container Apps settings
variable "container_image" {
  description = "Docker image for the Container App (ACR URI or public)"
  type        = string
  default     = "nginx:latest"
}

variable "container_cpu" {
  description = "Container App CPU cores"
  type        = number
  default     = 1.0
}

variable "container_memory" {
  description = "Container App memory (Gi)"
  type        = string
  default     = "2Gi"
}

# Database
variable "postgres_sku" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

# Cache
variable "redis_sku" {
  description = "Azure Cache for Redis SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Azure Cache for Redis family"
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Azure Cache for Redis capacity (0-6)"
  type        = number
  default     = 1
}
