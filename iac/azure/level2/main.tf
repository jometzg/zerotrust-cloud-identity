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
  }
}
 
provider "azurerm" {
  features {}
}
 
provider "azuread" {
}
 
# Get current subscription info automatically
data "azurerm_subscription" "current" {}
 
# Get user by UPN (if you know the email)
data "azuread_user" "azure_user" {
  user_principal_name = "gdsfed@MngEnvMCAP050695.onmicrosoft.com"
}
 
# Create Azure AD security group
resource "azuread_group" "readers" {
  display_name     = "Azure Readers"
  security_enabled = true
  description      = "Group for users with read-only access to Azure subscription for zero-trust poc"
}
 
# Add user to the Azure Readers group
resource "azuread_group_member" "reader_user" {
  group_object_id  = azuread_group.readers.object_id
  member_object_id = data.azuread_user.azure_user.object_id
}
 
# Assign Reader role to the group at subscription level
resource "azurerm_role_assignment" "reader_role" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.readers.object_id
}