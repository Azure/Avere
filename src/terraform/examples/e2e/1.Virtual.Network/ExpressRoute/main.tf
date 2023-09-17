terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.73.0"
    }
  }
}

provider "azurerm" {
  features {
  }
}

variable "regionName" {
  type = string
}

variable "resourceGroupName" {
  type = string
}

resource "azurerm_resource_group" "express_route" {
  name     = var.resourceGroupName
  location = var.regionName
}
