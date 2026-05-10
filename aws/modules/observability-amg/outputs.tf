output "workspace_id" {
  description = "AMG workspace ID"
  value       = aws_grafana_workspace.this.id
}

output "workspace_endpoint" {
  description = "AMG workspace endpoint (HTTPS URL for the Grafana UI)"
  value       = aws_grafana_workspace.this.endpoint
}
