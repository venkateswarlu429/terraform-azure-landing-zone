# -----------------------------------------------------------------------------
# Shared services — a central Key Vault, private-only by construction:
#   * public network access disabled; reachable solely via private endpoint
#     in the hub's SharedServicesSubnet
#   * Azure RBAC authorisation (no legacy access policies), so data-plane
#     access is governed by the same Entra ID role assignments as everything
#     else in the landing zone
#   * purge protection + 90-day soft delete, so secrets cannot be silently
#     destroyed — the configuration CAF mandates for shared vaults
# Workloads in any spoke resolve the vault name through the
# privatelink.vaultcore.azure.net zone the networking module links everywhere.
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_key_vault" "this" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC mode: access is granted with azurerm_role_assignment (below), never
  # with vault access policies.
  rbac_authorization_enabled = true

  purge_protection_enabled   = true
  soft_delete_retention_days = var.soft_delete_retention_days

  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${var.key_vault_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "key_vault" {
  for_each = { for idx, assignment in var.rbac_assignments : idx => assignment }

  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  description          = "Key Vault data-plane access granted from the shared-services module."
}

# Key Vault audit logs -> central Log Analytics workspace (monitoring pattern).
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "diag-kv-to-law"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
