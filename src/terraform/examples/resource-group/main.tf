variable "rg_name" {
  description = "resource group name."
  default = "test"
}
variable "rg_location" {
  description = "resource group location."
  default = "eastus"
}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
provider "azurerm" {
    version = "~>2.12.0"
    subscription_id = var.subscription_id
    client_id       = var.client_id
    client_secret   = var.client_secret
    tenant_id       = var.tenant_id
    features {}
}
resource "azurerm_resource_group" "rg" {
    name     = var.rg_name
    location = var.rg_location
}
