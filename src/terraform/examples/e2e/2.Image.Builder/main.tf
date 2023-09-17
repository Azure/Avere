terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.73.0"
    }
  }
  backend "azurerm" {
    key = "2.Image.Builder"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    template_deployment {
      delete_nested_items_during_deletion = true
    }
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

data "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

resource "azurerm_resource_group" "image" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

output "resourceGroupName" {
  value = azurerm_resource_group.image.name
}
