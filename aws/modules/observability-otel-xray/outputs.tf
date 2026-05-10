output "irsa_role_arn" {
  description = "IRSA role ARN for the OTel collector ServiceAccount"
  value       = aws_iam_role.otel_xray.arn
}

output "namespace" {
  description = "Kubernetes namespace the OTel collector deploys into"
  value       = var.namespace
}

output "service_account_name" {
  description = "ServiceAccount name bound to the IRSA role"
  value       = var.service_account_name
}
