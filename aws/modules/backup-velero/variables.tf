variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "EKS cluster name Velero runs against"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (for IRSA trust policy)"
  type        = string
}

variable "backup_bucket_name" {
  description = "S3 bucket name for Velero backups (created if create_bucket = true)"
  type        = string
}

variable "create_bucket" {
  description = "Create the backup bucket; false if it's pre-provisioned and shared"
  type        = bool
  default     = true
}

variable "schedule_cron" {
  description = "Cron expression for the default daily backup schedule"
  type        = string
  default     = "0 2 * * *"
}

variable "retention_days" {
  description = "Days to retain Velero backups before lifecycle deletion"
  type        = number
  default     = 30
}
