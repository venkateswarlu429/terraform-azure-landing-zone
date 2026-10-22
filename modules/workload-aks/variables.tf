variable "location" {
  description = "Azure region for the workload resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold the AKS cluster."
  type        = string
  default     = "rg-workload-aks-dev"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-alz-dev"
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster. For a private cluster this forms the private FQDN inside the system-managed private DNS zone."
  type        = string
  default     = "aks-alz-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster and node pools."
  type        = string
  default     = "1.30"
}

variable "node_subnet_id" {
  description = "Subnet ID for both node pools — the workload spoke's AKS subnet (networking module). Must already have the firewall route table associated."
  type        = string
}

variable "virtual_network_id" {
  description = "Resource ID of the workload spoke VNet. The cluster's managed identity is granted Network Contributor here so AKS can manage the node subnet and its route table association."
  type        = string
}

variable "route_table_id" {
  description = "Route table ID associated with the node subnet. The cluster identity is granted Network Contributor on it (required for outbound_type = userDefinedRouting). Leave empty to skip."
  type        = string
  default     = ""
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services. Must not overlap any VNet range or the pod CIDR plan."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP for the Kubernetes DNS service; must fall inside service_cidr."
  type        = string
  default     = "172.16.0.10"
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin via Azure RBAC. Replace the placeholder (00000000-0000-0000-0000-000000000000) with a real group before applying."
  type        = list(string)
  default     = ["00000000-0000-0000-0000-000000000000"]
}

variable "system_node_pool" {
  description = "System node pool sizing (runs system pods only; user workloads go to the user pool)."
  type = object({
    vm_size    = string
    node_count = number
    min_count  = number
    max_count  = number
  })
  default = {
    vm_size    = "Standard_D4s_v5"
    node_count = 2
    min_count  = 2
    max_count  = 5
  }
}

variable "user_node_pool" {
  description = "User node pool sizing."
  type = object({
    vm_size    = string
    node_count = number
    min_count  = number
    max_count  = number
  })
  default = {
    vm_size    = "Standard_D4s_v5"
    node_count = 2
    min_count  = 2
    max_count  = 10
  }
}

variable "user_node_pool_taints" {
  description = "Optional taints for the user node pool, e.g. [\"workload=batch:NoSchedule\"]. Empty means untainted."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID (monitoring module). Enables the OMS agent (Container Insights) and control-plane diagnostic settings."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
