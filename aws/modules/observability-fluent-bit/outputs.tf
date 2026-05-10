output "irsa_role_arn" {
  description = "IRSA role ARN to annotate the fluent-bit ServiceAccount with"
  value       = aws_iam_role.fluent_bit.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving pod logs"
  value       = aws_cloudwatch_log_group.pods.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.pods.arn
}
