output "workspace_id" {
  description = "AMP workspace ID"
  value       = aws_prometheus_workspace.this.id
}

output "workspace_arn" {
  description = "AMP workspace ARN"
  value       = aws_prometheus_workspace.this.arn
}

output "query_endpoint" {
  description = "AMP query endpoint (used as Prometheus datasource URL in Grafana)"
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}

output "remote_write_role_arn" {
  description = "IRSA role ARN for in-cluster Prometheus/OTel to remote-write into AMP"
  value       = aws_iam_role.amp_write.arn
}
