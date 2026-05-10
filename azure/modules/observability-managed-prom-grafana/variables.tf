variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the workspace + Grafana"
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

variable "admin_principal_ids" {
  description = "List of AAD principal object IDs granted Grafana Admin role"
  type        = list(string)
  default     = []
}
