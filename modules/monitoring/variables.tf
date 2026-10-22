variable "location" {
  description = "Azure region for the monitoring resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold the monitoring resources."
  type        = string
  default     = "rg-monitoring-dev"
}

variable "workspace_name" {
  description = "Name of the central Log Analytics workspace."
  type        = string
  default     = "law-alz-dev"
}

variable "retention_in_days" {
  description = "Data retention for the Log Analytics workspace, in days."
  type        = number
  default     = 90
}

variable "sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
