variable "location" {
  description = "Azure region for the shared services resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold the shared services."
  type        = string
  default     = "rg-shared-dev"
}

variable "key_vault_name" {
  description = "Globally unique name of the shared Key Vault (3-24 chars, alphanumeric and hyphens). Change this when adapting — Key Vault names are global."
  type        = string
  default     = "kv-alz-shared-dev"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{2,23}$", var.key_vault_name))
    error_message = "key_vault_name must be 3-24 characters, start with a letter, and contain only letters, numbers and hyphens."
  }
}

variable "soft_delete_retention_days" {
  description = "Key Vault soft-delete retention period in days."
  type        = number
  default     = 90
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID the Key Vault private endpoint is placed in (the hub SharedServicesSubnet from the networking module)."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the privatelink.vaultcore.azure.net Private DNS zone (from the networking module) for the private endpoint's DNS zone group."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Optional central Log Analytics workspace ID (from the monitoring module). When set, Key Vault diagnostic settings are created."
  type        = string
  default     = ""
}

variable "rbac_assignments" {
  description = <<-EOT
    Azure RBAC assignments on the Key Vault (data-plane roles), driven by variables.
    Replace the placeholder principal ID (00000000-0000-0000-0000-000000000000) with a real
    Entra ID user/group/service-principal object ID before applying.
  EOT
  type = list(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = [
    {
      principal_id         = "00000000-0000-0000-0000-000000000000" # TODO: platform team group object ID
      role_definition_name = "Key Vault Administrator"
    },
  ]
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
