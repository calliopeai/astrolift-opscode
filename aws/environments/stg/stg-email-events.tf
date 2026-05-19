# -----------------------------------------------------------------------------
# SES email event pipeline
#
# SES configuration sets (provisioned per-tenant by the platform's Django
# driver) publish email events to this SNS topic. SNS forwards to the
# platform's HTTPS webhook for ingest.
# -----------------------------------------------------------------------------

module "email_events" {
  count  = var.enable_email_events ? 1 : 0
  source = "../../modules/email-events-pipeline"

  name                 = local.name
  platform_webhook_url = "https://api-stg.${local.domain}/webhooks/ses-events/"

  tags = merge(local.tags, {
    Component = "email-events"
  })
}
