variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "project_id" {
  description = "GCP project hosting the GKE cluster"
  type        = string
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "GKE cluster name whose metrics get collected"
  type        = string
}

variable "wi_pool" {
  description = "Workload Identity pool (PROJECT_ID.svc.id.goog)"
  type        = string
}

variable "namespace" {
  description = "Namespace running Prometheus/OTel collectors that need WI"
  type        = string
  default     = "observability"
}
