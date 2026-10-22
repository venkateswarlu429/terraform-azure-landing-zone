output "management_group_ids" {
  description = "Map of management group keys to their resource IDs."
  value       = local.management_group_ids
}

output "root_management_group_id" {
  description = "Resource ID of the custom root management group."
  value       = azurerm_management_group.root.id
}

output "landing_zones_management_group_id" {
  description = "Resource ID of the Landing Zones management group."
  value       = azurerm_management_group.landing_zones.id
}

output "corp_management_group_id" {
  description = "Resource ID of the Corp management group."
  value       = azurerm_management_group.corp.id
}

output "policy_assignment_ids" {
  description = "Resource IDs of the policy assignments created by this module."
  value = {
    allowed_locations     = azurerm_management_group_policy_assignment.allowed_locations.id
    require_tag_on_rg     = azurerm_management_group_policy_assignment.require_tag_on_rg.id
    deny_public_ip_on_nic = azurerm_management_group_policy_assignment.deny_public_ip_on_nic.id
  }
}
