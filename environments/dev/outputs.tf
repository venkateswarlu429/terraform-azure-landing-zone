output "management_group_ids" {
  description = "Management group hierarchy created by the governance module."
  value       = module.governance.management_group_ids
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace receiving diagnostics from the firewall, Key Vault and AKS."
  value       = module.monitoring.log_analytics_workspace_id
}

output "firewall_private_ip_address" {
  description = "Hub firewall private IP — next hop for all spoke egress."
  value       = module.networking.firewall_private_ip_address
}

output "key_vault_uri" {
  description = "Shared Key Vault URI (private-endpoint only)."
  value       = module.shared_services.key_vault_uri
}

output "aks_cluster_name" {
  description = "Name of the private AKS cluster in the workload spoke."
  value       = module.workload_aks.cluster_name
}

output "aks_private_fqdn" {
  description = "Private API-server FQDN of the AKS cluster."
  value       = module.workload_aks.private_fqdn
}

output "aks_kubelet_identity_object_id" {
  description = "Kubelet identity object ID — grant it AcrPull when you add a container registry."
  value       = module.workload_aks.kubelet_identity_object_id
}
