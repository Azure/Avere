/*
*
*
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

### Variables

### Resources

### Outputs
