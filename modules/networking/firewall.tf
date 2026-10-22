# -----------------------------------------------------------------------------
# Azure Firewall in the hub — the single egress/inspection point for every
# spoke. Spoke route tables (routes.tf) point at this firewall's private IP,
# and the firewall policy below defines what is allowed out.
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  name                = "pip-azfw-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                = "azfw-policy-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.firewall_sku_tier

  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "spoke_egress" {
  name               = "spoke-egress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  # Platform plumbing every workload needs: DNS and NTP from the spokes.
  network_rule_collection {
    name     = "allow-platform-services"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP", "TCP"]
      source_addresses      = concat(var.workload_spoke_address_space, var.app_spoke_address_space)
      destination_addresses = ["168.63.129.16"] # Azure recursive resolver
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = concat(var.workload_spoke_address_space, var.app_spoke_address_space)
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  # AKS control-plane and image-pull endpoints. A private cluster still needs
  # outbound access to its (region-scoped) *.azmk8s.io endpoints unless a
  # private endpoint model is used — these FQDNs are the documented minimum.
  application_rule_collection {
    name     = "allow-aks-egress"
    priority = 200
    action   = "Allow"

    rule {
      name             = "aks-required-fqdns"
      source_addresses = var.workload_spoke_address_space
      destination_fqdns = [
        "*.hcp.${var.location}.azmk8s.io",
        "*.tun.${var.location}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net",
      ]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "azfw-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this.id

  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.hub["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.tags
}

# Firewall logs -> central Log Analytics workspace (monitoring module pattern).
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "diag-azfw-to-law"
  target_resource_id         = azurerm_firewall.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
