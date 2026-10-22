# -----------------------------------------------------------------------------
# Dev environment — providers and remote state.
#
# Provider layout follows CAF subscription democratisation: each platform
# area deploys into its own subscription, so this root module carries one
# azurerm provider alias per subscription and hands the right one to each
# module. All subscription IDs default to the placeholder
# 00000000-0000-0000-0000-000000000000 — replace them in terraform.tfvars
# (see terraform.tfvars.example) before planning against a real tenant.
#
# The governance module runs on the default provider: management-group and
# policy operations are tenant-scoped and are not tied to any one
# subscription's resources.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state in Azure Storage. The values below are EXAMPLES — point them
  # at your own state storage account, or override every value at init time:
  #   terraform init -backend-config=backend.conf
  # (see backend.conf.example). State storage itself is bootstrapped once,
  # outside this configuration.
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstatealz"
    container_name       = "tfstate"
    key                  = "landing-zone/dev.tfstate"
  }
}

provider "azurerm" {
  subscription_id = var.management_subscription_id
  features {}
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = var.connectivity_subscription_id
  features {}
}

provider "azurerm" {
  alias           = "management"
  subscription_id = var.management_subscription_id
  features {}
}

provider "azurerm" {
  alias           = "workload"
  subscription_id = var.workload_subscription_id
  features {}
}
