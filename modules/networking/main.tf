# -----------------------------------------------------------------------------
# Networking — hub-and-spoke topology (CAF connectivity subscription)
#
#   ┌──────────────────────────── HUB ────────────────────────────┐
#   │ AzureFirewallSubnet │ AzureBastionSubnet │ GatewaySubnet    │
#   │ SharedServicesSubnet (shared services + private endpoints)  │
#   └───────▲───────────────────────────────▲─────────────────────┘
#        peering                         peering        (no spoke <-> spoke)
#   ┌───────┴──────────────┐        ┌───────┴─────────────────────┐
#   │ WORKLOAD SPOKE      │        │ APP SPOKE                   │
#   │ snet-aks (AKS)      │        │ snet-app / snet-data        │
#   │ snet-app, snet-pe   │        │ snet-private-endpoints      │
#   └─────────────────────┘        └─────────────────────────────┘
#
# All spoke egress (internet AND cross-spoke) is forced through the hub
# Azure Firewall by user-defined routes — see routes.tf. Peering is
# hub<->spoke only, so spokes are isolated from each other by design.
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# --- Hub ----------------------------------------------------------------------

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.hub_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "hub" {
  for_each = var.hub_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = each.value
}

# --- Workload spoke (AKS landing zone) ----------------------------------------

resource "azurerm_virtual_network" "spoke_workload" {
  name                = "vnet-spoke-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.workload_spoke_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "spoke_workload" {
  for_each = var.workload_spoke_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke_workload.name
  address_prefixes     = each.value
}

# --- Application spoke (generic landing zone) ---------------------------------

resource "azurerm_virtual_network" "spoke_app" {
  name                = "vnet-spoke-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.app_spoke_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "spoke_app" {
  for_each = var.app_spoke_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke_app.name
  address_prefixes     = each.value
}
