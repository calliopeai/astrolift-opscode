output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "kube_config" {
  description = "AKS kubeconfig (sensitive)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "cluster_identity" {
  description = "AKS cluster managed identity principal ID"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "oidc_issuer_url" {
  description = "AKS cluster OIDC issuer URL (used by Workload Identity federated credentials)"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
