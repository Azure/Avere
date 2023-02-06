terraform {
  required_version = ">= 1.3.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.42.0"
    }
  }
  backend "azurerm" {
    key = "4.image.builder"
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
  source = "../0.global/module"
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
          gpuPlatform    = list(string)
          outputVersion  = string
          timeoutMinutes = number
          osDiskSizeGB   = number
          renderEngines  = list(string)
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

data "azurerm_user_assigned_identity" "render" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault" "render" {
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "service_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.render[0].id
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName
    key                  = "1.network"
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
  servicePassword    = var.servicePassword != "" ? var.servicePassword : data.azurerm_key_vault_secret.service_password
  stateExistsNetwork = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
}

resource "azurerm_resource_group" "image" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.render.principal_id
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
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.image.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "registry" {
  name                  = "${azurerm_container_registry.registry.name}.registry"
  resource_group_name   = azurerm_resource_group.image.name
  private_dns_zone_name = azurerm_private_dns_zone.registry.name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_endpoint" "farm" {
  name                = "${azurerm_container_registry.registry.name}.registry"
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  subnet_id           = data.azurerm_subnet.farm.id
  private_service_connection {
    name                           = azurerm_container_registry.registry.name
    private_connection_resource_id = azurerm_container_registry.registry.id
    is_manual_connection           = false
    subresource_names = [
      "registry"
    ]
  }
  private_dns_zone_group {
    name = azurerm_container_registry.registry.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.registry.id
    ]
  }
}

resource "azurerm_container_registry" "registry" {
  name                          = var.containerRegistry.name
  resource_group_name           = azurerm_resource_group.image.name
  location                      = azurerm_resource_group.image.location
  sku                           = var.containerRegistry.sku
  public_network_access_enabled = false
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.render.id
    ]
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
    "renderManager" = {
      value = module.global.renderManager
    }
    "managedIdentityName" = {
      value = module.global.managedIdentity.name
    }
    "managedIdentityResourceGroupName" = {
      value = module.global.resourceGroupName
    }
    "imageGalleryName" = {
      value = var.imageGallery.name
    }
    "imageTemplates" = {
      value = var.imageTemplates
    }
    "servicePassword" = {
      value = local.servicePassword
    }
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
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
        "imageBuilderApiVersion": "2022-02-14",
        "imageGalleryApiVersion": "2022-08-03"
      },
      "functions": [
        {
          "namespace": "fx",
          "members": {
            "GetCustomizeCommandsLinux": {
              "parameters": [
                {
                  "name": "imageTemplate",
                  "type": "object"
                },
                {
                  "name": "renderManager",
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/4.image.builder/customize.sh",
                    "destination": "/tmp/customize.sh"
                  },
                  {
                    "type": "File",
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/4.image.builder/onTerminate.sh",
                    "destination": "/tmp/onTerminate.sh"
                  },
                  {
                    "type": "Shell",
                    "inline": [
                      "[format('cat /tmp/customize.sh | tr -d \r | {0} /bin/bash', concat('buildConfigEncoded=', base64(string(union(parameters('imageTemplate').build, createObject('renderManager', parameters('renderManager')))))))]"
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/4.image.builder/customize.ps1",
                    "destination": "C:\\Users\\Public\\Downloads\\customize.ps1"
                  },
                  {
                    "type": "File",
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/4.image.builder/onTerminate.ps1",
                    "destination": "C:\\Users\\Public\\Downloads\\onTerminate.ps1"
                  },
                  {
                    "type": "PowerShell",
                    "inline": [
                      "[concat('C:\\Users\\Public\\Downloads\\customize.ps1 -buildConfigEncoded ', base64(string(union(parameters('imageTemplate').build, createObject('renderManager', parameters('renderManager')), createObject('servicePassword', parameters('servicePassword'))))))]"
                    ],
                    "runElevated": "[if(and(contains(parameters('renderManager'), 'Deadline'), equals(parameters('imageTemplate').build.machineType, 'Scheduler')), true(), false())]"
                  },
                  {
                    "type": "WindowsRestart"
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
              "version": "[parameters('imageTemplates')[copyIndex()].image.inputVersion]"
            },
            "customize": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('imageGalleryApiVersion')).osType, 'Windows'), fx.GetCustomizeCommandsWindows(parameters('imageTemplates')[copyIndex()], parameters('renderManager'), parameters('servicePassword')), fx.GetCustomizeCommandsLinux(parameters('imageTemplates')[copyIndex()], parameters('renderManager')))]",
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
    azurerm_shared_image.definitions
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
