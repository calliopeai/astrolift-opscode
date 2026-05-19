output "sns_topic_arn" {
  description = "ARN of the SNS topic SES publishes email events to. Set as ASTROLIFT_SES_EVENTS_SNS_TOPIC_ARN in the platform's environment."
  value       = aws_sns_topic.ses_events.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.ses_events.name
}

output "subscription_arn" {
  description = "ARN of the HTTPS subscription delivering events to the platform webhook"
  value       = aws_sns_topic_subscription.platform_webhook.arn
}
