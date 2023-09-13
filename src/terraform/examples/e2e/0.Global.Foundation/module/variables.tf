####################
# Global Variables #
####################

variable "regionNames" { # Set Azure region names from "az account list-locations --query [].name"
  default = [
    "WestUS2"
  ]
}

variable "resourceGroupName" {
  default = "ArtistAnywhere" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}

# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction)
variable "rootStorage" {
  default = {
    accountName = "azstudio0" # Set to a globally unique name (lowercase alphanumeric)
    containerName = {
      terraform = "terraform"
    }
  }
}

# Managed Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
variable "managedIdentity" {
  default = {
    name = "azstudio" # Alphanumeric, underscores and hyphens are allowed
  }
}

# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview)
variable "keyVault" {
  default = {
    name = "azstudio" # Set to a globally unique name (alphanumeric, hyphens)
    secretName = {
      gatewayConnection = "GatewayConnection"
      adminUsername     = "AdminUsername"
      adminPassword     = "AdminPassword"
    }
    keyName = {
      cacheEncryption = "CacheEncryption"
    }
    certificateName = {
    }
  }
}

# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview)
variable "monitor" {
  default = {
    name = "azstudio"
  }
}

output "regionNames" {
  value = var.regionNames
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "rootStorage" {
  value = var.rootStorage
}

output "managedIdentity" {
  value = var.managedIdentity
}

output "keyVault" {
  value = var.keyVault
}

output "monitor" {
  value = var.monitor
}
