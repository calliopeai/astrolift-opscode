variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "project_id" {
  description = "GCP project hosting the cluster + sink"
  type        = string
}

variable "wi_pool" {
  description = "Workload Identity pool (e.g. PROJECT_ID.svc.id.goog)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy fluent-bit into"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "ServiceAccount bound to the Workload Identity"
  type        = string
  default     = "fluent-bit"
}
