variable "name" {
  description = "Resource name prefix (e.g. dev-astrolift)"
  type        = string
}

variable "platform_webhook_url" {
  description = "HTTPS URL the platform exposes for SNS event delivery (e.g. https://api.example.com/webhooks/ses-events/). SNS will POST signed SES event envelopes to this endpoint."
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
