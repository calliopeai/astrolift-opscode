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
  description = "EKS cluster name to deploy the OTel collector into"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (for IRSA trust policy)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "observability"
}

variable "service_account_name" {
  description = "ServiceAccount name bound to the IRSA role"
  type        = string
  default     = "otel-collector"
}
