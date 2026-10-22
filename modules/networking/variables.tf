variable "location" {
  description = "Azure region for all networking resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold the connectivity (hub/spoke) resources."
  type        = string
  default     = "rg-connectivity-dev"
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}

# --- Address plan -------------------------------------------------------------
# Hub            10.0.0.0/16
# Workload spoke 10.1.0.0/16   (AKS landing zone)
# App spoke      10.2.0.0/16   (generic application landing zone)
# Ranges are deliberately non-overlapping and sized for growth; override via
# variables when adapting to a real estate plan.

variable "hub_address_space" {
  description = "Address space of the hub virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "hub_subnets" {
  description = "Hub subnets. AzureFirewallSubnet, AzureBastionSubnet and GatewaySubnet must keep those exact names — Azure requires them."
  type        = map(list(string))
  default = {
    AzureFirewallSubnet  = ["10.0.1.0/26"]
    AzureBastionSubnet   = ["10.0.2.0/26"]
    GatewaySubnet        = ["10.0.3.0/27"]
    SharedServicesSubnet = ["10.0.4.0/24"]
  }
}

variable "workload_spoke_address_space" {
  description = "Address space of the workload (AKS) spoke virtual network."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "workload_spoke_subnets" {
  description = "Workload spoke subnets. The AKS subnet is sized /20 because Azure CNI consumes one IP per pod."
  type        = map(list(string))
  default = {
    snet-aks               = ["10.1.0.0/20"]
    snet-app               = ["10.1.16.0/24"]
    snet-private-endpoints = ["10.1.17.0/24"]
  }
}

variable "app_spoke_address_space" {
  description = "Address space of the generic application spoke virtual network."
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "app_spoke_subnets" {
  description = "Application spoke subnets."
  type        = map(list(string))
  default = {
    snet-app               = ["10.2.0.0/24"]
    snet-data              = ["10.2.1.0/24"]
    snet-private-endpoints = ["10.2.2.0/24"]
  }
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion in the hub for private, browser-based VM access (no jump-box public IPs)."
  type        = bool
  default     = true
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier (Standard or Premium)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be \"Standard\" or \"Premium\"."
  }
}

variable "log_analytics_workspace_id" {
  description = "Optional central Log Analytics workspace ID (from the monitoring module). When set, firewall diagnostic settings are created."
  type        = string
  default     = ""
}
