variable "root_management_group_name" {
  description = "Name (ID segment) of the top-level custom management group, e.g. the CAF 'root' group that sits under the tenant root."
  type        = string
  default     = "alz"
}

variable "root_management_group_display_name" {
  description = "Display name of the top-level custom management group."
  type        = string
  default     = "Azure Landing Zone"
}

variable "parent_management_group_id" {
  description = "Resource ID of the parent management group for the root group. Leave null to parent directly under the tenant root management group."
  type        = string
  default     = null
}

variable "connectivity_subscription_ids" {
  description = "Subscription IDs to place in the Platform > Connectivity management group (hub networking subscription in a full CAF deployment)."
  type        = list(string)
  default     = []
}

variable "identity_subscription_ids" {
  description = "Subscription IDs to place in the Platform > Identity management group."
  type        = list(string)
  default     = []
}

variable "management_subscription_ids" {
  description = "Subscription IDs to place in the Platform > Management management group (logging / monitoring subscription)."
  type        = list(string)
  default     = []
}

variable "corp_subscription_ids" {
  description = "Subscription IDs to place in the Landing Zones > Corp management group (internal, privately-connected workloads)."
  type        = list(string)
  default     = []
}

variable "online_subscription_ids" {
  description = "Subscription IDs to place in the Landing Zones > Online management group (internet-facing workloads)."
  type        = list(string)
  default     = []
}

variable "allowed_locations" {
  description = "Azure regions permitted by the 'Allowed locations' policy assignment at the root management group."
  type        = list(string)
  default     = ["eastus2", "centralus"]
}

variable "required_tag_name" {
  description = "Tag that the 'Require a tag on resource groups' policy assignment enforces on every resource group."
  type        = string
  default     = "environment"
}

variable "policy_enforcement_enabled" {
  description = "Master switch for the policy assignments. Set to false to run the assignments in DoNotEnforce (audit-only) mode while onboarding."
  type        = bool
  default     = true
}

variable "rbac_assignments" {
  description = <<-EOT
    Role assignments to create at management-group scope, driven entirely by variables.
    `scope` is a key of the management-group map this module creates:
    root, platform, connectivity, identity, management, landing_zones, corp, online, sandbox, decommissioned.
    Replace the placeholder principal IDs (00000000-0000-0000-0000-000000000000) with real
    Entra ID group object IDs before applying — group-based assignment is the CAF recommendation.
  EOT
  type = map(object({
    scope                = string
    principal_id         = string
    role_definition_name = string
    description          = optional(string, "")
  }))
  default = {
    platform_readers = {
      scope                = "root"
      principal_id         = "00000000-0000-0000-0000-000000000000" # TODO: Entra ID group object ID (platform team)
      role_definition_name = "Reader"
      description          = "Platform team read access across the landing zone hierarchy."
    }
    corp_contributors = {
      scope                = "corp"
      principal_id         = "00000000-0000-0000-0000-000000000000" # TODO: Entra ID group object ID (workload team)
      role_definition_name = "Contributor"
      description          = "Workload team contributor access, scoped to Corp landing zones only."
    }
  }
}
