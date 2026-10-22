output "key_vault_id" {
  description = "Resource ID of the shared Key Vault."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Name of the shared Key Vault."
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "Vault URI (resolves to the private endpoint from inside the VNets)."
  value       = azurerm_key_vault.this.vault_uri
}

output "private_endpoint_id" {
  description = "Resource ID of the Key Vault private endpoint."
  value       = azurerm_private_endpoint.key_vault.id
}

output "resource_group_name" {
  description = "Name of the shared services resource group."
  value       = azurerm_resource_group.this.name
}
