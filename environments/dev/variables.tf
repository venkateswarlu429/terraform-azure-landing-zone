variable "location" {
  description = "Primary Azure region for the dev landing zone."
  type        = string
  default     = "eastus2"
}

variable "connectivity_subscription_id" {
  description = "Subscription ID for the connectivity (hub networking) subscription. Placeholder until adapted to a real tenant."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "management_subscription_id" {
  description = "Subscription ID for the management (logging/monitoring) subscription. Placeholder until adapted to a real tenant."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "workload_subscription_id" {
  description = "Subscription ID for the corp workload subscription that hosts the AKS spoke. Placeholder until adapted to a real tenant."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "corp_subscription_ids" {
  description = "All subscription IDs to place under the Corp management group (normally includes workload_subscription_id). Empty by default so the template never tries to associate the placeholder GUID."
  type        = list(string)
  default     = []
}

variable "allowed_locations" {
  description = "Regions the 'Allowed locations' policy permits."
  type        = list(string)
  default     = ["eastus2", "centralus"]
}

variable "key_vault_name" {
  description = "Globally unique name for the shared Key Vault."
  type        = string
  default     = "kv-alz-shared-dev"
}

variable "aks_admin_group_object_ids" {
  description = "Entra ID group object IDs granted AKS cluster-admin. Placeholder until adapted."
  type        = list(string)
  default     = ["00000000-0000-0000-0000-000000000000"]
}
