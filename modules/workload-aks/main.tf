# -----------------------------------------------------------------------------
# Workload — a private AKS cluster in the workload spoke.
#
# Security posture (CAF / AKS baseline):
#   * Private cluster: the API server has NO public endpoint; its DNS zone
#     lives inside the VNet, so kubectl only works from peered networks.
#   * Azure CNI: pods get real VNet IPs from the (firewall-routed) AKS
#     subnet — one IP per pod, hence the /20 subnet in the networking module.
#   * outbound_type = userDefinedRouting: ALL cluster egress goes through
#     the hub firewall. Requires the route table that the networking module
#     already associated with the node subnet, plus the Network Contributor
#     grants below so the cluster identity can read that route table.
#   * Entra ID + Azure RBAC for Kubernetes authorisation, local accounts
#     disabled; system/user node pool separation; Azure Policy add-on on so
#     Gatekeeper policies from the management-group assignments are enforced
#     inside the cluster too.
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  private_cluster_enabled             = true
  private_dns_zone_id                 = "System" # system-managed zone in the node resource group
  private_cluster_public_fqdn_enabled = false

  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_policy_enabled              = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.system_node_pool.vm_size
    node_count           = var.system_node_pool.node_count
    auto_scaling_enabled = true
    min_count            = var.system_node_pool.min_count
    max_count            = var.system_node_pool.max_count
    vnet_subnet_id       = var.node_subnet_id
    zones                = ["1", "2", "3"]
    os_disk_size_gb      = 128

    node_labels = {
      "nodepool-type" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
    # tenant_id intentionally omitted: defaults to the provider's tenant.
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  # Container Insights: node/pod logs and metrics -> central workspace.
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != "" ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_pool.vm_size
  mode                  = "User"
  node_count            = var.user_node_pool.node_count
  auto_scaling_enabled  = true
  min_count             = var.user_node_pool.min_count
  max_count             = var.user_node_pool.max_count
  vnet_subnet_id        = var.node_subnet_id
  zones                 = ["1", "2", "3"]
  os_disk_size_gb       = 128
  node_taints           = var.user_node_pool_taints

  node_labels = {
    "nodepool-type" = "user"
  }

  tags = var.tags
}

# --- Permissions the cluster identity needs for a custom-VNet + UDR design ----
# Without these, cluster creation fails: the managed identity must be able to
# join the subnet and read the route table that provides its egress path.

resource "azurerm_role_assignment" "aks_network_contributor_vnet" {
  scope                = var.virtual_network_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
  description          = "Lets the AKS managed identity manage its node subnet in the workload spoke."
}

resource "azurerm_role_assignment" "aks_network_contributor_route_table" {
  count = var.route_table_id != "" ? 1 : 0

  scope                = var.route_table_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
  description          = "Lets the AKS managed identity read the firewall route table used for userDefinedRouting egress."
}

# AKS control-plane logs (kube-apiserver, kube-audit, ...) -> central workspace.
resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "diag-aks-to-law"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
