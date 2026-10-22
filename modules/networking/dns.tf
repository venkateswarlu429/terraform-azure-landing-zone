# -----------------------------------------------------------------------------
# Private DNS for Azure Private Link.
#
# Private endpoints only stay private if every VNet resolves the service's
# privatelink zone to the endpoint IP. These zones are created once in the
# hub subscription and linked to the hub and BOTH spokes, so a private
# endpoint created in any of them resolves consistently across the estate.
# Zones provisioned here (extend the map as more PaaS services land):
#   blob  -> privatelink.blob.core.windows.net   (Storage)
#   vault -> privatelink.vaultcore.azure.net     (Key Vault — used by the
#                                                 shared-services module)
#   acr   -> privatelink.azurecr.io              (Container Registry)
# -----------------------------------------------------------------------------

locals {
  private_dns_zones = {
    blob  = "privatelink.blob.core.windows.net"
    vault = "privatelink.vaultcore.azure.net"
    acr   = "privatelink.azurecr.io"
  }

  # One link per (zone, VNet) pair: 3 zones x 3 VNets.
  private_dns_zone_vnet_links = merge([
    for zone_key, zone_name in local.private_dns_zones : {
      for vnet_key, vnet_id in {
        hub            = azurerm_virtual_network.hub.id
        spoke_workload = azurerm_virtual_network.spoke_workload.id
        spoke_app      = azurerm_virtual_network.spoke_app.id
      } :
      "${zone_key}-${vnet_key}" => {
        zone_key = zone_key
        vnet_id  = vnet_id
      }
    }
  ]...)
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_dns_zone_vnet_links

  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone_key].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}
