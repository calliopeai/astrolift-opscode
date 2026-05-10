output "monitor_workspace_id" {
  description = "Azure Monitor Workspace ID (Managed Prometheus)"
  value       = azurerm_monitor_workspace.main.id
}

output "monitor_workspace_query_endpoint" {
  description = "Managed Prometheus query endpoint"
  value       = azurerm_monitor_workspace.main.query_endpoint
}

output "grafana_endpoint" {
  description = "Managed Grafana workspace endpoint URL"
  value       = azurerm_dashboard_grafana.main.endpoint
}

output "grafana_id" {
  description = "Managed Grafana resource ID"
  value       = azurerm_dashboard_grafana.main.id
}
