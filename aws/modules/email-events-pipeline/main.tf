# -----------------------------------------------------------------------------
# SES email event pipeline
#
# SES configuration sets (provisioned per-tenant by the platform's Django
# driver) publish SEND / DELIVERY / BOUNCE / COMPLAINT / OPEN / CLICK events
# to this SNS topic. The platform subscribes via HTTPS and ingests events
# into its database.
#
# Topic policy restricts publishers to the SES service principal scoped to
# the platform's own account — a misconfigured external account can't
# publish noise into the topic.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "ses_events" {
  name = "${var.name}-ses-events"

  tags = merge(var.tags, {
    Name    = "${var.name}-ses-events"
    Purpose = "SES email event delivery"
  })
}

resource "aws_sns_topic_policy" "ses_events" {
  arn = aws_sns_topic.ses_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSESPublish"
        Effect    = "Allow"
        Principal = { Service = "ses.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.ses_events.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# HTTPS subscription — the platform's webhook endpoint receives SNS POST
# notifications, validates the signature, and ingests events. Subscription
# confirmation is handled automatically by the platform's SNS handler on
# first delivery.
#
# Raw delivery stays off: SNS wraps the SES notification in its own JSON
# envelope, which is what the platform expects for signature verification.
#
# Retry policy: SNS retries HTTPS endpoints with exponential backoff. The
# platform endpoint must respond 200 within 15s or SNS marks delivery
# failed.
resource "aws_sns_topic_subscription" "platform_webhook" {
  topic_arn            = aws_sns_topic.ses_events.arn
  protocol             = "https"
  endpoint             = var.platform_webhook_url
  raw_message_delivery = false
}
