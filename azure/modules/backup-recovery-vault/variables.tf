variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the vault"
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

variable "vault_sku" {
  description = "Recovery Services vault SKU (Standard or RS0)"
  type        = string
  default     = "Standard"
}

variable "soft_delete_enabled" {
  description = "Enable 14-day soft delete on the vault"
  type        = bool
  default     = true
}

variable "storage_mode_type" {
  description = "Backup storage redundancy (LocallyRedundant, GeoRedundant, ZoneRedundant)"
  type        = string
  default     = "LocallyRedundant"
}
