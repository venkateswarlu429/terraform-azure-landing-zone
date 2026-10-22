# -----------------------------------------------------------------------------
# Governance — CAF management group hierarchy, Azure Policy guardrails, RBAC
#
# Hierarchy (mirrors Microsoft's Cloud Adoption Framework enterprise-scale
# reference architecture):
#
#   Tenant Root
#   └── alz                       <- custom root created by this module
#       ├── platform
#       │   ├── connectivity      <- hub networking subscription
#       │   ├── identity
#       │   └── management        <- Log Analytics / automation subscription
#       ├── landing-zones
#       │   ├── corp              <- private/internal workloads (AKS spoke)
#       │   └── online            <- internet-facing workloads
#       ├── sandbox
#       └── decommissioned
# -----------------------------------------------------------------------------

# --- Management group hierarchy --------------------------------------------

resource "azurerm_management_group" "root" {
  name                       = var.root_management_group_name
  display_name               = var.root_management_group_display_name
  parent_management_group_id = var.parent_management_group_id
}

resource "azurerm_management_group" "platform" {
  name                       = "platform"
  display_name               = "Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "connectivity" {
  name                       = "connectivity"
  display_name               = "Connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
  subscription_ids           = var.connectivity_subscription_ids
}

resource "azurerm_management_group" "identity" {
  name                       = "identity"
  display_name               = "Identity"
  parent_management_group_id = azurerm_management_group.platform.id
  subscription_ids           = var.identity_subscription_ids
}

resource "azurerm_management_group" "management" {
  name                       = "management"
  display_name               = "Management"
  parent_management_group_id = azurerm_management_group.platform.id
  subscription_ids           = var.management_subscription_ids
}

resource "azurerm_management_group" "landing_zones" {
  name                       = "landing-zones"
  display_name               = "Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "corp" {
  name                       = "corp"
  display_name               = "Corp"
  parent_management_group_id = azurerm_management_group.landing_zones.id
  subscription_ids           = var.corp_subscription_ids
}

resource "azurerm_management_group" "online" {
  name                       = "online"
  display_name               = "Online"
  parent_management_group_id = azurerm_management_group.landing_zones.id
  subscription_ids           = var.online_subscription_ids
}

resource "azurerm_management_group" "sandbox" {
  name                       = "sandbox"
  display_name               = "Sandbox"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "decommissioned" {
  name                       = "decommissioned"
  display_name               = "Decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}

locals {
  management_group_ids = {
    root           = azurerm_management_group.root.id
    platform       = azurerm_management_group.platform.id
    connectivity   = azurerm_management_group.connectivity.id
    identity       = azurerm_management_group.identity.id
    management     = azurerm_management_group.management.id
    landing_zones  = azurerm_management_group.landing_zones.id
    corp           = azurerm_management_group.corp.id
    online         = azurerm_management_group.online.id
    sandbox        = azurerm_management_group.sandbox.id
    decommissioned = azurerm_management_group.decommissioned.id
  }

  # Built-in Azure Policy definitions used as guardrails. These are Microsoft's
  # real, tenant-independent definition IDs (last segment of the definition
  # resource ID), referenced so no custom policy JSON has to be maintained.
  builtin_policy_definitions = {
    # "Allowed locations" — restricts which regions resources can be deployed to.
    allowed_locations = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    # "Network interfaces should not have public IPs" — hard deny, no parameters.
    deny_public_ip_on_nic = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
    # "Require a tag on resource groups" — deny unless the tag exists (parameterised by tag name).
    require_tag_on_rg = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  }
}

# --- Policy assignments (guardrails, not gates: deny effects at MG scope) ----

# Region control applies everywhere, so it is assigned at the custom root and
# inherited by platform and landing-zone subscriptions alike.
resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations" # max 24 chars at MG scope
  display_name         = "Allowed locations for resources"
  description          = "Restricts deployments to the approved Azure regions only (data-residency guardrail)."
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.builtin_policy_definitions.allowed_locations
  enforce              = var.policy_enforcement_enabled

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })

  non_compliance_message {
    content = "Deployments are restricted to the approved regions defined by the platform team."
  }
}

# Cost/governance hygiene: every resource group must carry the required tag.
resource "azurerm_management_group_policy_assignment" "require_tag_on_rg" {
  name                 = "require-tag-on-rg"
  display_name         = "Require a tag on resource groups"
  description          = "Denies creation of resource groups that do not carry the '${var.required_tag_name}' tag."
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.builtin_policy_definitions.require_tag_on_rg
  enforce              = var.policy_enforcement_enabled

  parameters = jsonencode({
    tagName = {
      value = var.required_tag_name
    }
  })

  non_compliance_message {
    content = "Resource groups must carry the '${var.required_tag_name}' tag. Add the tag and retry the deployment."
  }
}

# Network exposure guardrail, scoped to landing zones only: platform
# subscriptions legitimately create public IPs (firewall, bastion, gateways),
# while workload NICs in corp/online must never get one directly.
resource "azurerm_management_group_policy_assignment" "deny_public_ip_on_nic" {
  name                 = "deny-pubip-on-nic"
  display_name         = "Network interfaces should not have public IPs"
  description          = "Denies attaching a public IP address directly to a network interface in landing-zone subscriptions."
  management_group_id  = azurerm_management_group.landing_zones.id
  policy_definition_id = local.builtin_policy_definitions.deny_public_ip_on_nic
  enforce              = var.policy_enforcement_enabled

  non_compliance_message {
    content = "Public IPs may not be attached directly to NICs in landing zones. Route via the hub firewall / a load balancer instead."
  }
}

# --- RBAC at management-group scope ------------------------------------------

resource "azurerm_role_assignment" "mg" {
  for_each = var.rbac_assignments

  scope                = local.management_group_ids[each.value.scope]
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  description          = each.value.description
}
