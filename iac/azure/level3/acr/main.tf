terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.29.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Get current subscription info automatically
data "azurerm_subscription" "current" {}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "acr_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location

}

resource "random_integer" "acr_suffix" {
  min = 10000
  max = 99999
}

resource "azurerm_container_registry" "acr" {
  name                = "zerotrustacr${random_integer.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.acr_rg.name
  location            = azurerm_resource_group.acr_rg.location
  sku                 = "Basic"
  admin_enabled       = false
}



# Variables for Azure AD configuration
variable "azure_client_id" {
  description = "Azure AD Application (client) ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
  sensitive   = true
}

# Resource Group name
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "zerotrust-acr-rg"
}

# Resource Group Location
variable "resource_group_location" {
  description = "Location of the resource group"
  type        = string
  default     = "uksouth"
}

# Outputs
output "acr_login_server" {
  description = "Azure Container Registry login server URL"
  value       = azurerm_container_registry.acr.login_server
}


