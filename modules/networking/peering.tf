# -----------------------------------------------------------------------------
# VNet peering — hub <-> each spoke. There is deliberately NO spoke <-> spoke
# peering: cross-spoke traffic must hairpin through the hub firewall (forced
# by the route tables in routes.tf), which keeps spokes isolated and gives
# one inspection point for east-west traffic.
#
# allow_forwarded_traffic is enabled on the hub side only: the hub VNet must
# accept packets the firewall forwards on behalf of a spoke. Gateway transit
# is left disabled because no VPN/ExpressRoute gateway is deployed yet — the
# GatewaySubnet is reserved; flip allow_gateway_transit/use_remote_gateways
# when a gateway is added.
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "hub_to_workload" {
  name                         = "peer-hub-to-workload"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_workload.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "workload_to_hub" {
  name                         = "peer-workload-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.spoke_workload.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_app" {
  name                         = "peer-hub-to-app"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_app.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "app_to_hub" {
  name                         = "peer-app-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.spoke_app.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
