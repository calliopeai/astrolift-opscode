variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "vault_kms_key_id" {
  description = "KMS key ID for backup vault encryption (null = AWS-managed)"
  type        = string
  default     = null
}

variable "rds_arns" {
  description = "RDS / Aurora instance + cluster ARNs to include in the plan"
  type        = list(string)
  default     = []
}

variable "efs_arns" {
  description = "EFS file system ARNs to include in the plan"
  type        = list(string)
  default     = []
}

variable "dynamodb_arns" {
  description = "DynamoDB table ARNs to include in the plan"
  type        = list(string)
  default     = []
}

variable "schedule_cron" {
  description = "Cron expression for the daily backup schedule"
  type        = string
  default     = "cron(0 5 ? * * *)"
}

variable "delete_after_days" {
  description = "Days to retain a recovery point before deletion"
  type        = number
  default     = 35
}

variable "cold_storage_after_days" {
  description = "Days after which a recovery point transitions to cold storage (null = no transition)"
  type        = number
  default     = null
}
