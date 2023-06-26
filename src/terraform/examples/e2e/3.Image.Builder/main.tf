terraform {
  required_version = ">= 1.4.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.60.0"
    }
  }
  backend "azurerm" {
    key = "3.Image.Builder"
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
  source = "../0.Global.Foundation/module"
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

variable "containerRegistry" {
  type = object(
    {
      name = string
      sku  = string
    }
  )
}

variable "imageTemplates" {
  type = list(object(
    {
      name = string
      image = object(
        {
          definitionName = string
          inputVersion   = string
        }
      )
      build = object(
        {
          machineType    = string
          machineSize    = string
          gpuProvider    = string
          outputVersion  = string
          timeoutMinutes = number
          osDiskSizeGB   = number
          renderEngines  = list(string)
          customize      = list(string)
        }
      )
    }
  ))
}

variable "servicePassword" {
  type = string
}

variable "computeNetwork" {
  type = object(
    {
      name              = string
      subnetName        = string
      resourceGroupName = string
    }
  )
}

data "http" "client_address" {
  url = "https://api.ipify.org?format=json"
}

data "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault" "studio" {
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "service_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.servicePassword
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "1.Virtual.Network"
  }
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

locals {
  stateExistsNetwork = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
  servicePassword    = var.servicePassword != "" ? var.servicePassword : data.azurerm_key_vault_secret.service_password[0].value
}

resource "azurerm_resource_group" "image" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = azurerm_resource_group.image.id
}

###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

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

#####################################################################################################
# Container Registry (https://learn.microsoft.com/zure/container-registry/container-registry-intro) #
#####################################################################################################

resource "azurerm_private_dns_zone" "registry" {
  count               = var.containerRegistry.name != "" ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.image.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "registry" {
  count                 = var.containerRegistry.name != "" ? 1 : 0
  name                  = "${azurerm_container_registry.studio[0].name}.registry"
  resource_group_name   = azurerm_resource_group.image.name
  private_dns_zone_name = azurerm_private_dns_zone.registry[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_endpoint" "farm" {
  count               = var.containerRegistry.name != "" ? 1 : 0
  name                = "${azurerm_container_registry.studio[0].name}.registry"
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  subnet_id           = data.azurerm_subnet.farm.id
  private_service_connection {
    name                           = azurerm_container_registry.studio[0].name
    private_connection_resource_id = azurerm_container_registry.studio[0].id
    is_manual_connection           = false
    subresource_names = [
      "registry"
    ]
  }
  private_dns_zone_group {
    name = azurerm_container_registry.studio[0].name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.registry[0].id
    ]
  }
}

resource "azurerm_container_registry" "studio" {
  count               = var.containerRegistry.name != "" ? 1 : 0
  name                = var.containerRegistry.name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  sku                 = var.containerRegistry.sku
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action    = "Allow"
      subnet_id = data.azurerm_subnet.farm.id
    }
    ip_rule {
      action   = "Allow"
      ip_range = jsondecode(data.http.client_address.response_body).ip
    }
  }
}

#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

resource "azurerm_resource_group_template_deployment" "image_builder" {
  name                = "ImageBuilder"
  resource_group_name = azurerm_resource_group.image.name
  deployment_mode     = "Incremental"
  parameters_content  = jsonencode({
    binStorageHost = {
      value = module.global.binStorage.host
    }
    binStorageAuth = {
      value = module.global.binStorage.auth
    }
    regionNames = {
      value = module.global.regionNames
    }
    renderManager = {
      value = module.global.renderManager
    }
    managedIdentityName = {
      value = module.global.managedIdentity.name
    }
    managedIdentityResourceGroupName = {
      value = module.global.resourceGroupName
    }
    imageGalleryName = {
      value = var.imageGallery.name
    }
    imageTemplates = {
      value = var.imageTemplates
    }
    servicePassword = {
      value = local.servicePassword
    }
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "binStorageHost": {
          "type": "string"
        },
        "binStorageAuth": {
          "type": "string"
        },
        "regionNames": {
          "type": "array"
        },
        "renderManager": {
          "type": "string"
        },
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
        "servicePassword": {
          "type": "string"
        }
      },
      "variables": {
        "imageBuilderApiVersion": "2022-07-01",
        "imageGalleryApiVersion": "2022-08-03"
      },
      "functions": [
        {
          "namespace": "fx",
          "members": {
            "GetCustomizeInlineCommands": {
              "parameters": [
                {
                  "name": "osType",
                  "type": "string"
                },
                {
                  "name": "inlineCommands",
                  "type": "array"
                }
              ],
              "output": {
                "type": "array",
                "value": [
                  {
                    "type": "[if(equals(parameters('osType'), 'Windows'), 'PowerShell', 'Shell')]",
                    "inline": "[parameters('inlineCommands')]"
                  }
                ]
              }
            },
            "GetCustomizeCommandsLinux": {
              "parameters": [
                {
                  "name": "imageTemplate",
                  "type": "object"
                },
                {
                  "name": "binStorageHost",
                  "type": "string"
                },
                {
                  "name": "binStorageAuth",
                  "type": "string"
                },
                {
                  "name": "renderManager",
                  "type": "string"
                },
                {
                  "name": "servicePassword",
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/3.Image.Builder/customize.sh",
                    "destination": "/tmp/customize.sh"
                  },
                  {
                    "type": "File",
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/3.Image.Builder/terminate.sh",
                    "destination": "/tmp/terminate.sh"
                  },
                  {
                    "type": "Shell",
                    "inline": [
                      "[format('cat /tmp/customize.sh | tr -d \r | {0} /bin/bash', concat('buildConfigEncoded=', base64(string(union(parameters('imageTemplate').build, createObject('binStorageHost', parameters('binStorageHost')), createObject('binStorageAuth', parameters('binStorageAuth')), createObject('renderManager', parameters('renderManager')), createObject('servicePassword', parameters('servicePassword')))))))]"
                    ]
                  }
                ]
              }
            },
            "GetCustomizeCommandsWindows": {
              "parameters": [
                {
                  "name": "imageTemplate",
                  "type": "object"
                },
                {
                  "name": "binStorageHost",
                  "type": "string"
                },
                {
                  "name": "binStorageAuth",
                  "type": "string"
                },
                {
                  "name": "renderManager",
                  "type": "string"
                },
                {
                  "name": "servicePassword",
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/3.Image.Builder/customize.ps1",
                    "destination": "C:\\AzureData\\customize.ps1"
                  },
                  {
                    "type": "File",
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/3.Image.Builder/terminate.ps1",
                    "destination": "C:\\AzureData\\terminate.ps1"
                  },
                  {
                    "type": "PowerShell",
                    "inline": [
                      "[concat('C:\\AzureData\\customize.ps1 -buildConfigEncoded ', base64(string(union(parameters('imageTemplate').build, createObject('binStorageHost', parameters('binStorageHost')), createObject('binStorageAuth', parameters('binStorageAuth')), createObject('renderManager', parameters('renderManager')), createObject('servicePassword', parameters('servicePassword'))))))]"
                    ],
                    "runElevated": "[if(and(contains(parameters('renderManager'), 'Deadline'), equals(parameters('imageTemplate').build.machineType, 'Scheduler')), true(), false())]"
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
              "publisher": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.publisher]",
              "offer": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.offer]",
              "sku": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.sku]",
              "version": "[parameters('imageTemplates')[copyIndex()].image.inputVersion]",
              "planInfo": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Linux'), json(concat('{\"planPublisher\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.publisher), '\", \"planProduct\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.offer), '\", \"planName\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).identifier.sku), '\"}')), json('null'))]"
            },
            "customize": "[if(greater(length(parameters('imageTemplates')[copyIndex()].build.customize), 0), fx.GetCustomizeInlineCommands(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, parameters('imageTemplates')[copyIndex()].build.customize), if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), fx.GetCustomizeCommandsWindows(parameters('imageTemplates')[copyIndex()], parameters('binStorageHost'), parameters('binStorageAuth'), parameters('renderManager'), parameters('servicePassword')), fx.GetCustomizeCommandsLinux(parameters('imageTemplates')[copyIndex()], parameters('binStorageHost'), parameters('binStorageAuth'), parameters('renderManager'), parameters('servicePassword'))))]",
            "buildTimeoutInMinutes": "[parameters('imageTemplates')[copyIndex()].build.timeoutMinutes]",
            "distribute": [
              {
                "type": "SharedImage",
                "runOutputName": "[concat(parameters('imageTemplates')[copyIndex()].name, '-', parameters('imageTemplates')[copyIndex()].build.outputVersion)]",
                "galleryImageId": "[resourceId('Microsoft.Compute/galleries/images/versions', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName, parameters('imageTemplates')[copyIndex()].build.outputVersion)]",
                "replicationRegions": "[parameters('regionNames')]",
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
    azurerm_shared_image.definitions
  ]
  lifecycle {
    ignore_changes = all
  }
}

output "resourceGroupName" {
  value = azurerm_resource_group.image.name
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
