output "vault_arn" {
  description = "AWS Backup vault ARN"
  value       = aws_backup_vault.this.arn
}

output "vault_name" {
  description = "AWS Backup vault name"
  value       = aws_backup_vault.this.name
}

output "plan_id" {
  description = "AWS Backup plan ID"
  value       = aws_backup_plan.this.id
}

output "service_role_arn" {
  description = "Service role AWS Backup uses for backup + restore operations"
  value       = aws_iam_role.backup.arn
}
