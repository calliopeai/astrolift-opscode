variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "amp_workspace_id" {
  description = "AMP workspace ID this Grafana instance reads from"
  type        = string
}

variable "amp_workspace_query_endpoint" {
  description = "AMP workspace query endpoint (used as Prometheus datasource URL)"
  type        = string
}

variable "admin_user_arns" {
  description = "List of IAM principal ARNs granted Grafana admin role"
  type        = list(string)
  default     = []
}

variable "authentication_provider" {
  description = "Authentication provider for the workspace (AWS_SSO or SAML)"
  type        = string
  default     = "AWS_SSO"

  validation {
    condition     = contains(["AWS_SSO", "SAML"], var.authentication_provider)
    error_message = "authentication_provider must be AWS_SSO or SAML."
  }
}
