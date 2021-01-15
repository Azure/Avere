variable "rg_name" {
  description = "resource group name."
  default = "test"
}
variable "rg_location" {
  description = "resource group location."
  default = "eastus"
}
provider "azurerm" {
    version = "~>2.12.0"
    features {}
}
resource "azurerm_resource_group" "rg" {
    name     = var.rg_name
    location = var.rg_location
}
