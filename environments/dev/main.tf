# -----------------------------------------------------------------------------
# Dev landing zone — composition root.
#
#   governance ── management groups + policy guardrails + MG-scope RBAC
#   monitoring ── central Log Analytics workspace (management subscription)
#   networking ── hub + 2 spokes, firewall, routes, Private DNS (connectivity)
#   shared     ── private Key Vault in the hub (connectivity)
#   aks        ── private AKS cluster in the workload spoke (corp workload sub)
#
# The `environment = "dev"` tag below is not decoration: the governance
# module assigns a policy that DENIES creating resource groups without it.
# -----------------------------------------------------------------------------

locals {
  tags = {
    environment = "dev"
    project     = "azure-landing-zone"
    owner       = "platform-team"
    managed_by  = "terraform"
  }
}

module "governance" {
  source = "../../modules/governance"

  allowed_locations     = var.allowed_locations
  required_tag_name     = "environment"
  corp_subscription_ids = var.corp_subscription_ids
  # Platform subscription placement is intentionally left empty in dev: add
  # the real subscription IDs when adapting (see terraform.tfvars.example).
}

module "monitoring" {
  source = "../../modules/monitoring"

  providers = {
    azurerm = azurerm.management
  }

  location            = var.location
  resource_group_name = "rg-monitoring-dev"
  workspace_name      = "law-alz-dev"
  tags                = local.tags
}

module "networking" {
  source = "../../modules/networking"

  providers = {
    azurerm = azurerm.connectivity
  }

  location                   = var.location
  resource_group_name        = "rg-connectivity-dev"
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.tags
}

module "shared_services" {
  source = "../../modules/shared-services"

  providers = {
    azurerm = azurerm.connectivity
  }

  location                   = var.location
  resource_group_name        = "rg-shared-dev"
  key_vault_name             = var.key_vault_name
  private_endpoint_subnet_id = module.networking.hub_shared_services_subnet_id
  private_dns_zone_id        = module.networking.private_dns_zone_ids["vault"]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.tags
}

module "workload_aks" {
  source = "../../modules/workload-aks"

  providers = {
    azurerm = azurerm.workload
  }

  location                   = var.location
  resource_group_name        = "rg-workload-aks-dev"
  cluster_name               = "aks-alz-dev"
  dns_prefix                 = "aks-alz-dev"
  node_subnet_id             = module.networking.workload_aks_subnet_id
  virtual_network_id         = module.networking.workload_spoke_virtual_network_id
  route_table_id             = module.networking.workload_route_table_id
  admin_group_object_ids     = var.aks_admin_group_object_ids
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.tags
}
