output "backup_bucket_name" {
  description = "S3 bucket Velero ships PV snapshots to"
  value       = var.backup_bucket_name
}

output "backup_bucket_arn" {
  description = "S3 bucket ARN"
  value       = local.bucket_arn
}

output "irsa_role_arn" {
  description = "IRSA role ARN to annotate the velero ServiceAccount with"
  value       = aws_iam_role.velero.arn
}
