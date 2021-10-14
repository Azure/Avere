terraform {
  required_version = ">= 1.0.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.80.0"
    }
  }
  backend "azurerm" {
    key = "4.compute.image"
  }
}

provider "azurerm" {
  features {}
}

module "global" {
  source = "../global"
}

variable "resourceGroupName" {
  type = string
}

variable "imageGalleryName" {
  type = string
}

variable "imageDefinitions" {
  type = list(
    object(
      {
        name       = string
        type       = string
        generation = string
        publisher  = string
        offer      = string
        sku        = string
      }
    )
  )
}

variable "imageTemplates" {
  type = list(
    object(
      {
        name                = string
        imageDefinitionName = string
        imageSourceType     = string
        imageScriptFile     = string
        imageSkuVersion     = string
        imageOutputVersion  = string
        buildTimeoutMinutes = number
        machineProfile = object(
          {
            sizeSku      = string
            subnetName   = string
            osDiskSizeGB = number
          }
        )
      }
    )
  )
}

variable "storage" {
  type = object(
    {
      accountName        = string
      accountType        = string
      accountRedundancy  = string
      accountPerformance = string
      containerName      = string
    }
  )
}

locals {
  fileNameCustomizeLinux   = "customize.sh"
  fileNameCustomizeWindows = "customize.ps1"
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "1.network"
  }
}

data "azurerm_user_assigned_identity" "identity" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_resource_group" "network" {
  name = data.terraform_remote_state.network.outputs.resourceGroupName
}

resource "azurerm_resource_group" "image" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_storage_account" "storage" {
  name                     = var.storage.accountName
  resource_group_name      = azurerm_resource_group.image.name
  location                 = azurerm_resource_group.image.location
  account_kind             = var.storage.accountType
  account_replication_type = var.storage.accountRedundancy
  account_tier             = var.storage.accountPerformance
}

resource "azurerm_role_assignment" "network" {
  role_definition_name = "Virtual Machine Contributor" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = data.azurerm_resource_group.network.id
}

resource "azurerm_role_assignment" "storage" {
  role_definition_name = "Storage Blob Data Reader" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-reader
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_storage_account.storage.id
}

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_resource_group.image.id
}

resource "azurerm_storage_container" "container" {
  name                 = var.storage.containerName
  storage_account_name = azurerm_storage_account.storage.name
}

resource "azurerm_storage_blob" "customize_linux" {
  name                   = local.fileNameCustomizeLinux
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.fileNameCustomizeLinux
  type                   = "Block"
}

resource "azurerm_storage_blob" "customize_windows" {
  name                   = local.fileNameCustomizeWindows
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.fileNameCustomizeWindows
  type                   = "Block"
}

resource "azurerm_shared_image_gallery" "gallery" {
  name                = var.imageGalleryName
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
}

resource "azurerm_shared_image" "definitions" {
  count               = length(var.imageDefinitions)
  name                = var.imageDefinitions[count.index].name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  os_type             = var.imageDefinitions[count.index].type
  hyper_v_generation  = var.imageDefinitions[count.index].generation
  identifier {
    publisher = var.imageDefinitions[count.index].publisher
    offer     = var.imageDefinitions[count.index].offer
    sku       = var.imageDefinitions[count.index].sku
  }
}

resource "azurerm_resource_group_template_deployment" "image_builder" {
  name                = "ImageBuilder"
  resource_group_name = azurerm_resource_group.image.name
  deployment_mode     = "Incremental"
  parameters_content  = jsonencode({
    "managedIdentityName" = {
      value = module.global.managedIdentityName
    },
    "managedIdentityResourceGroupName" = {
      value = module.global.securityResourceGroupName
    },
    "imageGalleryName" = {
      value = var.imageGalleryName
    },
    "imageTemplates" = {
      value = var.imageTemplates
    },
    "imageScriptContainer" = {
      value = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.container.name}/"
    },
    "virtualNetworkName" = {
      value = data.terraform_remote_state.network.outputs.virtualNetwork.name
    },
    "virtualNetworkResourceGroupName" = {
      value = data.terraform_remote_state.network.outputs.resourceGroupName
    }
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "managedIdentityName": {
          "type": "string"
        },
        "managedIdentityResourceGroupName": {
          "type": "string"
        },
        "imageGalleryName": {
          "type": "string"
        },
        "imageTemplates": {
          "type": "array"
        },
        "imageScriptContainer": {
          "type": "string"
        },
        "virtualNetworkName": {
          "type": "string"
        },
        "virtualNetworkResourceGroupName": {
          "type": "string"
        }
      },
      "variables": {
        "imageBuilderApiVersion": "2020-02-14",
        "imageGalleryApiVersion": "2021-07-01"
      },
      "functions": [
        {
          "namespace": "fx",
          "members": {
            "GetExecuteCommandLinux": {
              "parameters": [
                {
                  "name": "scriptFile",
                  "type": "string"
                },
                {
                  "name": "scriptParameters",
                  "type": "object"
                }
              ],
              "output": {
                "type": "string",
                "value": "[format('cat {0} | tr -d \r | {1} /bin/bash', parameters('scriptFile'), replace(replace(replace(replace(replace(string(parameters('scriptParameters')), '{', ''), '}', ''), '\"', ''), ':', '='), ',', ' '))]"
              }
            },
            "GetExecuteCommandWindows": {
              "parameters": [
                {
                  "name": "scriptFile",
                  "type": "string"
                },
                {
                  "name": "scriptParameters",
                  "type": "object"
                }
              ],
              "output": {
                "type": "string",
                "value": "[format('PowerShell -ExecutionPolicy Unrestricted -File {0} {1}', parameters('scriptFile'), replace(replace(replace(replace(replace(string(parameters('scriptParameters')), ',\"', ' -'), '\"', ''), ':', ' '), '{', '-'), '}', ''))]"
              }
            }
          }
        }
      ],
      "resources": [
        {
          "type": "Microsoft.VirtualMachineImages/imageTemplates",
          "name": "[parameters('imageTemplates')[copyIndex()].name]",
          "apiVersion": "[variables('imageBuilderApiVersion')]",
          "location": "[resourceGroup().location]",
          "identity": {
            "type": "UserAssigned",
            "userAssignedIdentities": {
              "[resourceId(parameters('managedIdentityResourceGroupName'), 'Microsoft.ManagedIdentity/userAssignedIdentities', parameters('managedIdentityName'))]": {
              }
            }
          },
          "properties": {
            "vmProfile": {
              "vmSize": "[parameters('imageTemplates')[copyIndex()].machineProfile.sizeSku]",
              "osDiskSizeGB": "[parameters('imageTemplates')[copyIndex()].machineProfile.osDiskSizeGB]",
              "vnetConfig": {
                "subnetId": "[resourceId(parameters('virtualNetworkResourceGroupName'), 'Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworkName'), parameters('imageTemplates')[copyIndex()].machineProfile.subnetName)]"
              }
            },
            "source": {
              "type": "[parameters('imageTemplates')[copyIndex()].imageSourceType]",
              "publisher": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName), variables('imageGalleryApiVersion')).identifier.publisher]",
              "offer": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName), variables('imageGalleryApiVersion')).identifier.offer]",
              "sku": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName), variables('imageGalleryApiVersion')).identifier.sku]",
              "version": "[parameters('imageTemplates')[copyIndex()].imageSkuVersion]"
            },
            "customize": [
              {
                "type": "File",
                "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()].imageScriptFile)]",
                "destination": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), concat('%TMP%\\', parameters('imageTemplates')[copyIndex()].imageScriptFile), concat('/tmp/', parameters('imageTemplates')[copyIndex()].imageScriptFile))]"
              },
              {
                "type": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), 'PowerShell', 'Shell')]",
                "inline": "[createArray(if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), fx.GetExecuteCommandWindows(parameters('imageTemplates')[copyIndex()].imageScriptFile, parameters('imageTemplates')[copyIndex()].machineProfile), fx.GetExecuteCommandLinux(parameters('imageTemplates')[copyIndex()].imageScriptFile, parameters('imageTemplates')[copyIndex()].machineProfile)))]"
              }
            ],
            "buildTimeoutInMinutes": "[parameters('imageTemplates')[copyIndex()].buildTimeoutMinutes]",
            "distribute": [
              {
                "type": "SharedImage",
                "runOutputName": "[concat(parameters('imageTemplates')[copyIndex()].name, '-', parameters('imageTemplates')[copyIndex()].imageOutputVersion)]",
                "galleryImageId": "[resourceId('Microsoft.Compute/galleries/images/versions', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].imageDefinitionName, parameters('imageTemplates')[copyIndex()].imageOutputVersion)]",
                "replicationRegions": [
                  "[resourceGroup().location]"
                ],
                "artifactTags": {
                  "imageTemplateName": "[parameters('imageTemplates')[copyIndex()].name]"
                }
              }
            ]
          },
          "copy": {
            "name": "imageTemplates",
            "count": "[length(parameters('imageTemplates'))]"
          }
        }
      ],
      "outputs": {
      }
    }
  TEMPLATE
  depends_on = [
    azurerm_shared_image.definitions,
    azurerm_storage_blob.customize_linux,
    azurerm_storage_blob.customize_windows
  ]
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "imageGalleryName" {
  value = var.imageGalleryName
}

output "imageDefinitions" {
  value = var.imageDefinitions
}

output "imageTemplates" {
  value = var.imageTemplates
}
