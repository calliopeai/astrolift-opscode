variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "project_id" {
  description = "GCP project hosting the Cloud SQL instance"
  type        = string
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}

variable "instance_name" {
  description = "Cloud SQL instance name to apply backup policy to"
  type        = string
}

variable "retention_days" {
  description = "Backup retention in days (7-365)"
  type        = number
  default     = 30
  validation {
    condition     = var.retention_days >= 7 && var.retention_days <= 365
    error_message = "retention_days must be between 7 and 365."
  }
}

variable "enable_pitr" {
  description = "Enable point-in-time recovery (binary log retention)"
  type        = bool
  default     = true
}

variable "export_bucket_name" {
  description = "GCS bucket for scheduled SQL exports (null = skip exports)"
  type        = string
  default     = null
}
