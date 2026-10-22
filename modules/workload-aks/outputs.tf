output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "private_fqdn" {
  description = "Private FQDN of the cluster API server (resolvable only from inside the peered VNets)."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "cluster_identity_principal_id" {
  description = "Principal (object) ID of the cluster's system-assigned managed identity."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity — grant this AcrPull on a container registry to enable image pulls."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "node_resource_group" {
  description = "Name of the managed node resource group created by AKS."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "resource_group_name" {
  description = "Name of the workload resource group."
  value       = azurerm_resource_group.this.name
}
