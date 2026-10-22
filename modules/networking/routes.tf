# -----------------------------------------------------------------------------
# Forced tunnelling — user-defined routes on every spoke subnet send:
#   * 0.0.0.0/0            -> Azure Firewall (all internet egress inspected)
#   * the hub address space -> Azure Firewall (spoke -> hub shared services
#                              are inspected too, rather than silently riding
#                              the peering's system routes)
# Spoke -> spoke traffic follows the default route into the firewall, which
# is the only path between spokes (there is no spoke <-> spoke peering).
#
# The AKS subnet association is load-bearing: the AKS cluster in the
# workload-aks module uses outbound_type = "userDefinedRouting", which
# requires a route table with a 0.0.0.0/0 route on the node subnet.
# -----------------------------------------------------------------------------

resource "azurerm_route_table" "spoke_workload" {
  name                = "rt-spoke-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
  }

  route {
    name                   = "hub-via-firewall"
    address_prefix         = var.hub_address_space[0]
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
  }

  tags = var.tags
}

resource "azurerm_route_table" "spoke_app" {
  name                = "rt-spoke-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
  }

  route {
    name                   = "hub-via-firewall"
    address_prefix         = var.hub_address_space[0]
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "spoke_workload" {
  for_each = azurerm_subnet.spoke_workload

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.spoke_workload.id
}

resource "azurerm_subnet_route_table_association" "spoke_app" {
  for_each = azurerm_subnet.spoke_app

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.spoke_app.id
}

# --- Baseline NSGs on spoke subnets -------------------------------------------
# Defence in depth alongside the firewall: VNet-internal traffic is allowed,
# unsolicited inbound from the Internet is denied at the subnet edge. (The
# governance module's policy additionally denies public IPs on NICs, so this
# is a second, independent control.)

resource "azurerm_network_security_group" "spoke_workload" {
  name                = "nsg-spoke-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "spoke_app" {
  name                = "nsg-spoke-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke_workload" {
  for_each = azurerm_subnet.spoke_workload

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.spoke_workload.id
}

resource "azurerm_subnet_network_security_group_association" "spoke_app" {
  for_each = azurerm_subnet.spoke_app

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.spoke_app.id
}
