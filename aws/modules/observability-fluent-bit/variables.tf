variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "tags" {
  description = "Resource tags applied to every taggable resource"
  type        = map(string)
  default     = {}
}

variable "cluster_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (used for IRSA trust policy)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group to ship pod logs into"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "KMS key ID for log group encryption (null = AWS-managed)"
  type        = string
  default     = null
}
