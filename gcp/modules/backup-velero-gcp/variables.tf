variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "project_id" {
  description = "GCP project hosting the cluster + backup bucket"
  type        = string
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "GKE cluster name Velero runs against"
  type        = string
}

variable "wi_pool" {
  description = "Workload Identity pool"
  type        = string
}

variable "backup_bucket_name" {
  description = "GCS bucket name for Velero backups (created if create_bucket = true)"
  type        = string
}

variable "create_bucket" {
  description = "Create the backup bucket; false if pre-provisioned"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Days to retain Velero backups before lifecycle deletion"
  type        = number
  default     = 30
}
