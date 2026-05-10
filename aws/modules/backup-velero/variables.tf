variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
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

variable "retention_days" {
  description = "Days to retain Velero backups before lifecycle deletion"
  type        = number
  default     = 30
}
