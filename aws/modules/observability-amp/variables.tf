variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region for the AMP workspace"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name whose metrics get scraped"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (for IRSA write-side role)"
  type        = string
}

variable "alert_manager_definition" {
  description = "Optional AlertManager definition YAML (null = workspace default)"
  type        = string
  default     = null
}
