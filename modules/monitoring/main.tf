# -----------------------------------------------------------------------------
# Monitoring — central Log Analytics workspace (CAF "management" subscription)
#
# This module owns the single workspace that the rest of the landing zone
# streams diagnostics into. The diagnostic-settings *pattern* is applied by
# each consuming module (networking -> firewall, shared-services -> Key Vault,
# workload-aks -> AKS control plane), always pointing at this workspace ID:
#
#   resource "azurerm_monitor_diagnostic_setting" "example" {
#     target_resource_id         = <resource>.id
#     log_analytics_workspace_id = var.log_analytics_workspace_id  # from here
#     enabled_log { category_group = "allLogs" }
#     enabled_metric { category = "AllMetrics" }
#   }
#
# Centralising the workspace (rather than one per workload) is what enables
# cross-subscription KQL, a single Sentinel instance and one retention policy.
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.sku
  retention_in_days   = var.retention_in_days

  tags = var.tags
}
