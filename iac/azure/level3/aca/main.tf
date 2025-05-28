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

resource "azurerm_resource_group" "aca_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location

}

# Create a Log Analytics workspace for Container App Environment
resource "azurerm_log_analytics_workspace" "aca_logs" {
  name                = "zerotrust-aca-logs"
  location            = azurerm_resource_group.acr_rg.location
  resource_group_name = azurerm_resource_group.acr_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Create Container App Environment
resource "azurerm_container_app_environment" "aca_env" {
  name                       = "zerotrust-aca-env"
  location                   = azurerm_resource_group.acr_rg.location
  resource_group_name        = azurerm_resource_group.acr_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aca_logs.id
}

# Create a user-assigned managed identity for Container App to access ACR
resource "azurerm_user_assigned_identity" "aca_identity" {
  name                = "zerotrust-aca-identity"
  location            = azurerm_resource_group.acr_rg.location
  resource_group_name = azurerm_resource_group.acr_rg.name
}

# Grant the managed identity AcrPull role on the container registry
resource "azurerm_role_assignment" "aca_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_identity.principal_id
}

# Create Container App
resource "azurerm_container_app" "workload_app" {
  name                         = "zerotrust-workload-app"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = azurerm_resource_group.acr_rg.name
  revision_mode               = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca_identity.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.aca_identity.id
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "workload-app"
      image  = "${azurerm_container_registry.acr.login_server}/zerotrust-workload:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PORT"
        value = "8080"
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      # Azure AD configuration for authentication
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.azure_client_id
      }

      env {
        name  = "AZURE_TENANT_ID"
        value = var.azure_tenant_id
      }
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port              = 8080
    transport                = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
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

output "container_app_fqdn" {
  description = "Container App fully qualified domain name"
  value       = azurerm_container_app.workload_app.latest_revision_fqdn
}

output "container_app_url" {
  description = "Container App URL"
  value       = "https://${azurerm_container_app.workload_app.latest_revision_fqdn}"
}

