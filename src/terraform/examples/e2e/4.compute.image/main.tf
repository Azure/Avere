terraform {
  required_version = ">= 1.1.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.90.0"
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
        name = string
        image = object(
          {
            definitionName = string
            sourceType     = string
            customizer     = string
            terminater     = string
            inputVersion   = string
            outputVersion  = string
          }
        )
        build = object(
          {
            subnetName     = string
            machineSize    = string
            osDiskSizeGB   = number
            timeoutMinutes = number
            userName       = string
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

locals {
  customizerLinux   = "customize.sh"
  customizerWindows = "customize.ps1"
  terminaterLinux   = "terminate.sh"
  terminaterWindows = "terminate.ps1"
}

data "terraform_remote_state" "network" {
  count   = var.virtualNetwork.name == "" ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "1.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.name : var.virtualNetwork.name
  resource_group_name  = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.resourceGroupName : var.virtualNetwork.resourceGroupName
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.network.resource_group_name
}

data "azurerm_user_assigned_identity" "identity" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "user_password" {
  name         = module.global.keyVaultSecretNameUserPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_storage_account" "storage" {
  name                = module.global.terraformStorageAccountName
  resource_group_name = module.global.securityResourceGroupName
}

resource "azurerm_resource_group" "image" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_role_assignment" "network" {
  role_definition_name = "Virtual Machine Contributor" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = data.azurerm_resource_group.network.id
}

resource "azurerm_role_assignment" "storage" {
  role_definition_name = "Storage Blob Data Reader" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-reader
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = data.azurerm_storage_account.storage.id
}

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_resource_group.image.id
}

resource "azurerm_storage_container" "container" {
  name                 = "image"
  storage_account_name = data.azurerm_storage_account.storage.name
}

resource "azurerm_storage_blob" "customizer_linux" {
  name                   = local.customizerLinux
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.customizerLinux
  type                   = "Block"
}

resource "azurerm_storage_blob" "customizer_windows" {
  name                   = local.customizerWindows
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.customizerWindows
  type                   = "Block"
}

resource "azurerm_storage_blob" "terminater_linux" {
  name                   = local.terminaterLinux
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.terminaterLinux
  type                   = "Block"
}

resource "azurerm_storage_blob" "terminater_windows" {
  name                   = local.terminaterWindows
  storage_account_name   = data.azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  source                 = local.terminaterWindows
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
    "userPassword" = {
      value = data.azurerm_key_vault_secret.user_password.value
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
        "userPassword": {
          "type": "string"
        }
      },
      "variables": {
        "imageBuilderApiVersion": "2020-02-14",
        "imageGalleryApiVersion": "2021-07-01",
        "localDownloadPathLinux": "/tmp/",
        "localDownloadPathWindows": "C:\\Windows\\Temp\\"
      },
      "functions": [
        {
          "namespace": "fx",
          "members": {
            "GetExecuteCommandLinux": {
              "parameters": [
                {
                  "name": "scriptFilePath",
                  "type": "string"
                },
                {
                  "name": "scriptFileName",
                  "type": "string"
                },
                {
                  "name": "scriptParameters",
                  "type": "object"
                },
                {
                  "name": "userPassword",
                  "type": "string"
                }
              ],
              "output": {
                "type": "string",
                "value": "[format('cat {0} | tr -d \r | {1} /bin/bash', concat(parameters('scriptFilePath'), parameters('scriptFileName')), concat(replace(replace(replace(replace(string(parameters('scriptParameters')), ',\"', ' '), '\":', '='), '{\"', ''), '}', ''), ' userPassword=', parameters('userPassword')))]"
              }
            },
            "GetExecuteCommandWindows": {
              "parameters": [
                {
                  "name": "scriptFilePath",
                  "type": "string"
                },
                {
                  "name": "scriptFileName",
                  "type": "string"
                },
                {
                  "name": "scriptParameters",
                  "type": "object"
                },
                {
                  "name": "userPassword",
                  "type": "string"
                }
              ],
              "output": {
                "type": "string",
                "value": "[format('{0} {1}', concat(parameters('scriptFilePath'), parameters('scriptFileName')), concat(replace(replace(replace(replace(string(parameters('scriptParameters')), ',\"', ' -'), '\":', ' '), '{\"', '-'), '}', ''), ' -userPassword ', parameters('userPassword')))]"
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
            "customize": [
              {
                "type": "File",
                "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()].image.customizer)]",
                "destination": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), concat(variables('localDownloadPathWindows'), parameters('imageTemplates')[copyIndex()].image.customizer), concat(variables('localDownloadPathLinux'), parameters('imageTemplates')[copyIndex()].image.customizer))]"
              },
              {
                "type": "File",
                "sourceUri": "[concat(parameters('imageScriptContainer'), parameters('imageTemplates')[copyIndex()].image.terminater)]",
                "destination": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), concat(variables('localDownloadPathWindows'), parameters('imageTemplates')[copyIndex()].image.terminater), concat(variables('localDownloadPathLinux'), parameters('imageTemplates')[copyIndex()].image.terminater))]"
              },
              {
                "type": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), 'PowerShell', 'Shell')]",
                "inline": "[createArray(if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), fx.GetExecuteCommandWindows(variables('localDownloadPathWindows'), parameters('imageTemplates')[copyIndex()].image.customizer, parameters('imageTemplates')[copyIndex()].build, parameters('userPassword')), fx.GetExecuteCommandLinux(variables('localDownloadPathLinux'), parameters('imageTemplates')[copyIndex()].image.customizer, parameters('imageTemplates')[copyIndex()].build, parameters('userPassword'))))]"
              }
            ],
            "buildTimeoutInMinutes": "[parameters('imageTemplates')[copyIndex()].build.timeoutMinutes]",
            "distribute": [
              {
                "type": "SharedImage",
                "runOutputName": "[concat(parameters('imageTemplates')[copyIndex()].name, '-', parameters('imageTemplates')[copyIndex()].image.outputVersion)]",
                "galleryImageId": "[resourceId('Microsoft.Compute/galleries/images/versions', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName, parameters('imageTemplates')[copyIndex()].image.outputVersion)]",
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
            "mode": "serial",
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
    azurerm_storage_blob.customizer_linux,
    azurerm_storage_blob.customizer_windows,
    azurerm_storage_blob.terminater_linux,
    azurerm_storage_blob.terminater_windows
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
