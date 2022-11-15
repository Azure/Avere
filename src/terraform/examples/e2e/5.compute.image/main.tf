terraform {
  required_version = ">= 1.3.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.31.0"
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
      delete_nested_items_during_deletion = false
    }
  }
}

module "global" {
  source = "../0.global"
}

variable "resourceGroupName" {
  type = string
}

variable "imageGallery" {
  type = object(
    {
      name = string
      imageDefinitions = list(object(
        {
          name       = string
          type       = string
          generation = string
          publisher  = string
          offer      = string
          sku        = string
        }
      ))
    }
  )
}

variable "imageTemplates" {
  type = list(object(
    {
      name = string
      image = object(
        {
          definitionName   = string
          customizeScript  = string
          terminateScript1 = string
          terminateScript2 = string
          inputVersion     = string
        }
      )
      build = object(
        {
          machineType    = string
          machineSize    = string
          gpuPlatform    = list(string)
          osDiskSizeGB   = number
          timeoutMinutes = number
          outputVersion  = string
          renderManager  = string
          renderEngines  = list(string)
        }
      )
    }
  ))
}

variable "computeNetwork" {
  type = object(
    {
      name              = string
      resourceGroupName = string
    }
  )
}

data "azurerm_user_assigned_identity" "solution" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "solution" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  name         = module.global.keyVaultSecretNameAdminUsername
  key_vault_id = data.azurerm_key_vault.solution.id
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.solution.id
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_storage_account" "storage" {
  name                = module.global.securityStorageAccountName
  resource_group_name = module.global.securityResourceGroupName
}

locals {
  stateExistsNetwork      = try(length(data.terraform_remote_state.network.outputs) >= 0, false)
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
  role_definition_name = "Virtual Machine Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = data.azurerm_resource_group.network.id
}

resource "azurerm_role_assignment" "storage" {
  role_definition_name = "Storage Blob Data Reader" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = data.azurerm_storage_account.storage.id
}

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
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
  name                = var.imageGallery.name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
}

resource "azurerm_shared_image" "definitions" {
  count               = length(var.imageGallery.imageDefinitions)
  name                = var.imageGallery.imageDefinitions[count.index].name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  os_type             = var.imageGallery.imageDefinitions[count.index].type
  hyper_v_generation  = var.imageGallery.imageDefinitions[count.index].generation
  identifier {
    publisher = var.imageGallery.imageDefinitions[count.index].publisher
    offer     = var.imageGallery.imageDefinitions[count.index].offer
    sku       = var.imageGallery.imageDefinitions[count.index].sku
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
      value = var.imageGallery.name
    },
    "imageTemplates" = {
      value = var.imageTemplates
    },
    "imageScriptContainer" = {
      value = "https://${data.azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.container.name}/"
    },
    "keyVaultSecretAdminUsername" = {
      value = data.azurerm_key_vault_secret.admin_username.value
    }
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
        "keyVaultSecretAdminUsername": {
          "type": "string"
        },
        "keyVaultSecretAdminPassword": {
          "type": "string"
        }
      },
      "variables": {
        "imageBuilderApiVersion": "2022-02-14",
        "imageGalleryApiVersion": "2022-08-03",
        "localDownloadPathLinux": "/tmp/",
        "localDownloadPathWindows": "/Windows/Temp/"
      },
      "functions": [
        {
          "namespace": "fx",
          "members": {
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
                  "name": "adminUsername",
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
                    "type": "Shell",
                    "inline": [
                      "[concat('hostname ', parameters('imageTemplate').name)]"
                    ]
                  },
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
                      "[format('cat {0} | tr -d \r | {1} /bin/bash', concat(parameters('scriptFilePath'), parameters('imageTemplate').image.customizeScript), concat('buildConfigEncoded=', base64(string(union(parameters('imageTemplate').build, createObject('adminUsername', parameters('adminUsername')), createObject('adminPassword', parameters('adminPassword')))))))]"
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
                    "type": "PowerShell",
                    "inline": [
                      "[concat('Rename-Computer -NewName ', parameters('imageTemplate').name)]"
                    ]
                  },
                  {
                    "type": "WindowsRestart"
                  },
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
                      "[format('{0} {1}', concat(parameters('scriptFilePath'), parameters('imageTemplate').image.customizeScript), concat('-buildConfigEncoded ', base64(string(parameters('imageTemplate').build))))]"
                    ],
                    "runElevated": "[if(equals(parameters('imageTemplate').build.machineType, 'Scheduler'), true(), false())]"
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
              "osDiskSizeGB": "[parameters('imageTemplates')[copyIndex()].build.osDiskSizeGB]"
            },
            "source": {
              "type": "PlatformImage",
              "planInfo": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Linux'), json(concat('{\"planName\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.sku), '\", \"planProduct\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.offer), '\", \"planPublisher\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.publisher), '\"}')), json('null'))]",
              "publisher": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.publisher]",
              "offer": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.offer]",
              "sku": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.sku]",
              "version": "[parameters('imageTemplates')[copyIndex()].image.inputVersion]"
            },
            "customize": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), fx.GetCustomizeCommandsWindows(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()], variables('localDownloadPathWindows')), fx.GetCustomizeCommandsLinux(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()], variables('localDownloadPathLinux'), parameters('keyVaultSecretAdminUsername'), parameters('keyVaultSecretAdminPassword')))]",
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

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "imageGallery" {
  value = var.imageGallery
}

output "imageTemplates" {
  value = var.imageTemplates
}

output "imageDefinitionsLinux" {
  value = [
    for imageDefinition in var.imageGallery.imageDefinitions: imageDefinition if imageDefinition.type == "Linux"
  ]
}
