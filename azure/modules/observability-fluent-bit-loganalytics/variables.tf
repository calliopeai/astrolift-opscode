variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the AKS cluster + Log Analytics workspace"
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
  description = "AKS cluster OIDC issuer URL (for workload identity federation)"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID receiving pod logs"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace running fluent-bit"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "ServiceAccount bound to the federated identity"
  type        = string
  default     = "fluent-bit"
}
