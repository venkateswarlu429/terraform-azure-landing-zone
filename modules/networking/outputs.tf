output "resource_group_name" {
  description = "Name of the connectivity resource group."
  value       = azurerm_resource_group.this.name
}

output "hub_virtual_network_id" {
  description = "Resource ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "workload_spoke_virtual_network_id" {
  description = "Resource ID of the workload spoke virtual network."
  value       = azurerm_virtual_network.spoke_workload.id
}

output "app_spoke_virtual_network_id" {
  description = "Resource ID of the application spoke virtual network."
  value       = azurerm_virtual_network.spoke_app.id
}

output "hub_shared_services_subnet_id" {
  description = "Subnet ID of the hub SharedServicesSubnet — hosts shared services and their private endpoints (e.g. Key Vault)."
  value       = azurerm_subnet.hub["SharedServicesSubnet"].id
}

output "workload_aks_subnet_id" {
  description = "Subnet ID of the workload spoke's AKS subnet (route table with firewall UDR already associated)."
  value       = azurerm_subnet.spoke_workload["snet-aks"].id
}

output "workload_private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints in the workload spoke."
  value       = azurerm_subnet.spoke_workload["snet-private-endpoints"].id
}

output "app_private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints in the application spoke."
  value       = azurerm_subnet.spoke_app["snet-private-endpoints"].id
}

output "firewall_private_ip_address" {
  description = "Private IP of the hub Azure Firewall — the next hop used by every spoke route table."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "workload_route_table_id" {
  description = "Route table ID associated with the workload spoke subnets (the AKS cluster identity needs access to it)."
  value       = azurerm_route_table.spoke_workload.id
}

output "app_route_table_id" {
  description = "Route table ID associated with the application spoke subnets."
  value       = azurerm_route_table.spoke_app.id
}

output "private_dns_zone_ids" {
  description = "Map of Private DNS zone keys (blob, vault, acr) to resource IDs, for use in private endpoint DNS zone groups."
  value       = { for key, zone in azurerm_private_dns_zone.this : key => zone.id }
}
