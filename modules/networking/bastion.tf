# -----------------------------------------------------------------------------
# Azure Bastion in the hub — private operator access to spoke VMs without
# any public IP on the workload NICs (pairs with the deny-public-IP policy
# in the governance module).
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "pip-bastion-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count = var.enable_bastion ? 1 : 0

  name                = "bastion-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.hub["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = var.tags
}
