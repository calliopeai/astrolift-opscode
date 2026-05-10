variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the cluster + storage"
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

variable "subscription_id" {
  description = "Subscription ID for the cluster + storage"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name for Velero backups (created if create_storage = true)"
  type        = string
}

variable "container_name" {
  description = "Blob container name within the storage account"
  type        = string
  default     = "velero"
}

variable "create_storage" {
  description = "Create the storage account; false if pre-provisioned"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Days to retain Velero backups (used for blob lifecycle policy)"
  type        = number
  default     = 30
}
