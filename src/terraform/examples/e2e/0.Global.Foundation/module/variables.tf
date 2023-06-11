####################
# Global Variables #
####################

variable "regionNames" { # Set Azure region names from "az account list-locations --query [].name"
  default = [
    "WestUS3",
    "EastUS2"
  ]
}

variable "resourceGroupName" {
  default = "ArtistAnywhere" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}

variable "renderManager" {
  default = "Deadline,Flamenco,RoyalRender"
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
      servicePassword   = "ServicePassword"
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

variable "binStorage" {
  default = {
    host = "https://azstudio.blob.core.windows.net/bin"
    auth = "?sv=2021-10-04&st=2022-01-01T00%3A00%3A00Z&se=9999-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=SyE2RuK0C7M9nNQSJfiw4SenqqV8O6DYulr24ZJapFw%3D"
  }
}

output "regionNames" {
  value = var.regionNames
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

output "monitor" {
  value = var.monitor
}

output "binStorage" {
  value = var.binStorage
}
