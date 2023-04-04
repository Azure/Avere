####################
# Global Variables #
####################

variable "regionName" {
  default = "WestUS2" # Set default Azure region name (az account list-locations --query [].name)
}

variable "resourceGroupName" {
  default = "ArtistAnywhere" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}

variable "renderManager" {
  default = "RoyalRender,Deadline,Qube"
}

# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction)
variable "rootStorage" {
  default = {
    accountName   = "azrender0" # Set to a globally unique name (lowercase alphanumeric)
    containerName = "terraform"
  }
}

# Managed Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
variable "managedIdentity" {
  default = {
    name = "azrender" # Alphanumeric, underscores and hyphens are allowed
  }
}

# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview)
variable "keyVault" {
  default = {
    name = "" # Set to a globally unique name (alphanumeric, hyphens)
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
variable "monitorWorkspace" {
  default = {
    name = ""
  }
}

output "regionName" {
  value = var.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "renderManager" {
  value = var.renderManager
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

output "monitorWorkspace" {
  value = var.monitorWorkspace
}
