output "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace. Pass this to every other module so its resources stream diagnostics here."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  description = "Name of the central Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace (customer) ID used by agents and VM extensions."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "resource_group_name" {
  description = "Name of the monitoring resource group."
  value       = azurerm_resource_group.this.name
}
