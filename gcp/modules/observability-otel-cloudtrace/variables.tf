variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "project_id" {
  description = "GCP project hosting the trace span sink"
  type        = string
}

variable "wi_pool" {
  description = "Workload Identity pool"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the OTel collector"
  type        = string
  default     = "observability"
}

variable "service_account_name" {
  description = "ServiceAccount bound to the Workload Identity"
  type        = string
  default     = "otel-collector"
}
