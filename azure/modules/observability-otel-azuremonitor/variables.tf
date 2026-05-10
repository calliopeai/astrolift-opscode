variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the cluster + UAMI"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "aks_oidc_issuer_url" {
  description = "AKS cluster OIDC issuer URL"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the OTel collector"
  type        = string
  default     = "observability"
}

variable "service_account_name" {
  description = "ServiceAccount bound to the federated identity"
  type        = string
  default     = "otel-collector"
}

variable "application_insights_id" {
  description = "Optional Application Insights resource ID; null = collector exports to Monitor metrics + logs only"
  type        = string
  default     = null
}
