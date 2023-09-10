terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.72.0"
    }
  }
  backend "azurerm" {
    key = "2.Image.Builder"
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
        }
      )
    }
  ))
}

variable "binStorage" {
  type = object(
    {
      host = string
      auth = string
    }
  )
  validation {
    condition     = var.binStorage.host != "" && var.binStorage.auth != ""
    error_message = "Missing required deployment configuration."
  }
}

data "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
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

#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

resource "azurerm_resource_group_template_deployment" "image_builder" {
  name                = "ImageBuilder"
  resource_group_name = azurerm_resource_group.image.name
  deployment_mode     = "Incremental"
  parameters_content  = jsonencode({
    binStorage = {
      value = var.binStorage
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
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "binStorage": {
          "type": "object"
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
        }
      },
      "variables": {
        "apiVersionImageBuilder": "2022-07-01",
        "apiVersionImageGallery": "2023-07-03"
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
                  "name": "binStorage",
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/customize.sh",
                    "destination": "/tmp/customize.sh"
                  },
                  {
                    "type": "File",
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/terminate.sh",
                    "destination": "/tmp/terminate.sh"
                  },
                  {
                    "type": "Shell",
                    "inline": [
                      "[format('cat /tmp/customize.sh | tr -d \r | {0} /bin/bash', concat('buildConfigEncoded=', base64(string(union(parameters('imageTemplate').build, createObject('binStorage', parameters('binStorage')), createObject('renderManager', parameters('renderManager')))))))]"
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
                  "name": "binStorage",
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/customize.ps1",
                    "destination": "C:\\AzureData\\customize.ps1"
                  },
                  {
                    "type": "File",
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/terminate.ps1",
                    "destination": "C:\\AzureData\\terminate.ps1"
                  },
                  {
                    "type": "PowerShell",
                    "inline": [
                      "[concat('C:\\AzureData\\customize.ps1 -buildConfigEncoded ', base64(string(union(parameters('imageTemplate').build, createObject('binStorage', parameters('binStorage')), createObject('renderManager', parameters('renderManager'))))))]"
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
          "apiVersion": "[variables('apiVersionImageBuilder')]",
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
              "publisher": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).identifier.publisher]",
              "offer": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).identifier.offer]",
              "sku": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).identifier.sku]",
              "version": "[parameters('imageTemplates')[copyIndex()].image.inputVersion]",
              "planInfo": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).osType, 'Linux'), json(concat('{\"planPublisher\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).identifier.publisher), '\", \"planProduct\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).identifier.offer), '\", \"planName\": \"', toLower(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).identifier.sku), '\"}')), json('null'))]"
            },
            "customize": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('imageGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionImageGallery')).osType, 'Windows'), fx.GetCustomizeCommandsWindows(parameters('imageTemplates')[copyIndex()], parameters('binStorage'), parameters('renderManager')), fx.GetCustomizeCommandsLinux(parameters('imageTemplates')[copyIndex()], parameters('binStorage'), parameters('renderManager')))]",
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

output "imageDefinitionLinux" {
  value = one([
    for imageDefinition in var.imageGallery.imageDefinitions: imageDefinition if imageDefinition.type == "Linux"
  ])
}
