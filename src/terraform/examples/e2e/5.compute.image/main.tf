terraform {
  required_version = ">= 1.2.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.12.0"
    }
  }
  backend "azurerm" {
    key = "5.compute.image"
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
  source = "../0.global"
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
        name = string
        image = object(
          {
            definitionName   = string
            sourceType       = string
            customizeScript  = string
            terminateScript1 = string
            terminateScript2 = string
            inputVersion     = string
          }
        )
        build = object(
          {
            subnetName     = string
            machineSize    = string
            osDiskSizeGB   = number
            timeoutMinutes = number
            outputVersion  = string
            runElevated    = bool
            renderEngines  = list(string)
          }
        )
      }
    )
  )
}

variable "virtualNetwork" {
  type = object(
    {
      name              = string
      resourceGroupName = string
    }
  )
}

data "azurerm_user_assigned_identity" "identity" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "terraform_remote_state" "network" {
  count   = var.virtualNetwork.name == "" ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.network.resource_group_name
}

data "azurerm_virtual_network" "network" {
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.name : var.virtualNetwork.name
  resource_group_name  = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.resourceGroupName : var.virtualNetwork.resourceGroupName
}

data "azurerm_storage_account" "storage" {
  name                = module.global.securityStorageAccountName
  resource_group_name = module.global.securityResourceGroupName
}

locals {
  customizeScriptLinux    = "customize.sh"
  customizeScriptWindows  = "customize.ps1"
  terminateScript1Linux   = "terminate.sh"
  terminateScript1Windows = "terminate.ps1"
  terminateScript2Linux   = "onTerminate.sh"
  terminateScript2Windows = "onTerminate.ps1"
}

resource "azurerm_resource_group" "image" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_role_assignment" "network" {
  role_definition_name = "Virtual Machine Contributor" // https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = data.azurerm_resource_group.network.id
}

resource "azurerm_role_assignment" "storage" {
  role_definition_name = "Storage Blob Data Reader" // https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = data.azurerm_storage_account.storage.id
}

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" // https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_resource_group.image.id
}

resource "azurerm_storage_container" "container" {
  name                 = "image"
  storage_account_name = data.azurerm_storage_account.storage.name
}

resource "azurerm_storage_blob" "customize_script_linux" {
  name                   = local.customizeScriptLinux
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.customizeScriptLinux
  type                   = "Block"
}

resource "azurerm_storage_blob" "customize_script_windows" {
  name                   = local.customizeScriptWindows
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.customizeScriptWindows
  type                   = "Block"
}

resource "azurerm_storage_blob" "terminate_script1_linux" {
  name                   = local.terminateScript1Linux
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.terminateScript1Linux
  type                   = "Block"
}

resource "azurerm_storage_blob" "terminate_script1_windows" {
  name                   = local.terminateScript1Windows
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.terminateScript1Windows
  type                   = "Block"
}

resource "azurerm_storage_blob" "terminate_script2_linux" {
  name                   = local.terminateScript2Linux
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.terminateScript2Linux
  type                   = "Block"
}

resource "azurerm_storage_blob" "terminate_script2_windows" {
  name                   = local.terminateScript2Windows
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.terminateScript2Windows
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
      value = "https://${data.azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.container.name}/"
    },
    "virtualNetworkName" = {
      value = data.azurerm_virtual_network.network.name
    },
    "virtualNetworkResourceGroupName" = {
      value = data.azurerm_virtual_network.network.resource_group_name
    },
    "keyVaultSecretAdminPassword" = {
      value = data.azurerm_key_vault_secret.admin_password.value
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
        },
        "keyVaultSecretAdminPassword": {
          "type": "string"
        }
      },
      "variables": {
        "imageBuilderApiVersion": "2022-02-14",
        "imageGalleryApiVersion": "2022-03-03",
        "localDownloadPathLinux": "/tmp/",
        "localDownloadPathWindows": "/Windows/Temp/"
      },
      "functions": [
        {
          "namespace": "fx",
          "members": {
            "GetMachineRenameCommands": {
              "parameters": [
                {
                  "name": "osType",
                  "type": "string"
                },
                {
                  "name": "imageTemplate",
                  "type": "object"
                }
              ],
              "output": {
                "type": "array",
                "value": [
                  {
                    "type": "[if(equals(parameters('osType'), 'Windows'), 'PowerShell', 'Shell')]",
                    "inline": "[createArray(if(equals(parameters('osType'), 'Windows'), concat('Rename-Computer -NewName ', parameters('imageTemplate').name), concat('hostname ', parameters('imageTemplate').name)))]"
                  },
                  {
                    "type": "[if(equals(parameters('osType'), 'Windows'), 'WindowsRestart', 'Shell')]",
                    "inline": "[if(equals(parameters('osType'), 'Windows'), json('null'), createArray(':'))]"
                  }
                ]
              }
            },
            "GetCustomizeCommandsLinux": {
              "parameters": [
                {
                  "name": "imageScriptContainer",
                  "type": "string"
                },
                {
                  "name": "imageTemplate",
                  "type": "object"
                },
                {
                  "name": "scriptFilePath",
                  "type": "string"
                },
                {
                  "name": "adminPassword",
                  "type": "string"
                }
              ],
              "output": {
                "type": "array",
                "value": [
                  {
                    "type": "File",
                    "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplate').image.customizeScript)]",
                    "destination": "[concat(parameters('scriptFilePath'), parameters('imageTemplate').image.customizeScript)]"
                  },
                  {
                    "type": "File",
                    "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplate').image.terminateScript1)]",
                    "destination": "[concat(parameters('scriptFilePath'), parameters('imageTemplate').image.terminateScript1)]"
                  },
                  {
                    "type": "File",
                    "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplate').image.terminateScript2)]",
                    "destination": "[concat(parameters('scriptFilePath'), parameters('imageTemplate').image.terminateScript2)]"
                  },
                  {
                    "type": "Shell",
                    "inline": [
                      "[format('cat {0} | tr -d \r | {1} /bin/bash', concat(parameters('scriptFilePath'), parameters('imageTemplate').image.customizeScript), concat('buildJsonEncoded=', base64(string(union(parameters('imageTemplate').build, createObject('adminPassword', parameters('adminPassword')))))))]"
                    ]
                  }
                ]
              }
            },
            "GetCustomizeCommandsWindows": {
              "parameters": [
                {
                  "name": "imageScriptContainer",
                  "type": "string"
                },
                {
                  "name": "imageTemplate",
                  "type": "object"
                },
                {
                  "name": "scriptFilePath",
                  "type": "string"
                }
              ],
              "output": {
                "type": "array",
                "value": [
                  {
                    "type": "File",
                    "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplate').image.customizeScript)]",
                    "destination": "[concat(parameters('scriptFilePath'), parameters('imageTemplate').image.customizeScript)]"
                  },
                  {
                    "type": "File",
                    "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplate').image.terminateScript1)]",
                    "destination": "[concat(parameters('scriptFilePath'), parameters('imageTemplate').image.terminateScript1)]"
                  },
                  {
                    "type": "File",
                    "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplate').image.terminateScript2)]",
                    "destination": "[concat(parameters('scriptFilePath'), parameters('imageTemplate').image.terminateScript2)]"
                  },
                  {
                    "type": "PowerShell",
                    "inline": [
                      "[format('{0} {1}', concat(parameters('scriptFilePath'), parameters('imageTemplate').image.customizeScript), concat('-buildJsonEncoded ', base64(string(parameters('imageTemplate').build))))]"
                    ],
                    "runElevated": "[parameters('imageTemplate').build.runElevated]"
                  }
                ]
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
              "vmSize": "[parameters('imageTemplates')[copyIndex()].build.machineSize]",
              "osDiskSizeGB": "[parameters('imageTemplates')[copyIndex()].build.osDiskSizeGB]",
              "vnetConfig": {
                "subnetId": "[resourceId(parameters('virtualNetworkResourceGroupName'), 'Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworkName'), parameters('imageTemplates')[copyIndex()].build.subnetName)]"
              }
            },
            "source": {
              "type": "[parameters('imageTemplates')[copyIndex()].image.sourceType]",
              "publisher": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.publisher]",
              "offer": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.offer]",
              "sku": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.sku]",
              "version": "[parameters('imageTemplates')[copyIndex()].image.inputVersion]"
            },
            "customize": "[concat(if(equals(parameters('imageTemplates')[copyIndex()].build.outputVersion, '0.0.0'), fx.GetMachineRenameCommands(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, parameters('imageTemplates')[copyIndex()]), createArray()), if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), fx.GetCustomizeCommandsWindows(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()], variables('localDownloadPathWindows')), fx.GetCustomizeCommandsLinux(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()], variables('localDownloadPathLinux'), parameters('keyVaultSecretAdminPassword'))))]",
            "buildTimeoutInMinutes": "[parameters('imageTemplates')[copyIndex()].build.timeoutMinutes]",
            "distribute": [
              {
                "type": "SharedImage",
                "runOutputName": "[concat(parameters('imageTemplates')[copyIndex()].name, '-', parameters('imageTemplates')[copyIndex()].build.outputVersion)]",
                "galleryImageId": "[resourceId('Microsoft.Compute/galleries/images/versions', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName, parameters('imageTemplates')[copyIndex()].build.outputVersion)]",
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
    azurerm_storage_blob.customize_script_linux,
    azurerm_storage_blob.customize_script_windows,
    azurerm_storage_blob.terminate_script1_linux,
    azurerm_storage_blob.terminate_script1_windows,
    azurerm_storage_blob.terminate_script2_linux,
    azurerm_storage_blob.terminate_script2_windows
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
