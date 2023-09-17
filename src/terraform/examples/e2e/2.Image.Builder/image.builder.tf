#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

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

resource "azurerm_role_assignment" "image" {
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = azurerm_resource_group.image.id
}

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
    managedIdentityName = {
      value = module.global.managedIdentity.name
    }
    managedIdentityResourceGroupName = {
      value = module.global.resourceGroupName
    }
    computeGalleryName = {
      value = var.computeGallery.name
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
        "managedIdentityName": {
          "type": "string"
        },
        "managedIdentityResourceGroupName": {
          "type": "string"
        },
        "computeGalleryName": {
          "type": "string"
        },
        "imageTemplates": {
          "type": "array"
        }
      },
      "variables": {
        "apiVersionImageBuilder": "2022-07-01",
        "apiVersionComputeGallery": "2023-07-03"
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/0.Global.Foundation/functions.sh",
                    "destination": "/tmp/functions.sh"
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
                      "[format('cat /tmp/customize.sh | tr -d \r | {0} /bin/bash', concat('buildConfigEncoded=', base64(string(union(parameters('imageTemplate').build, createObject('binStorage', parameters('binStorage')))))))]"
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
                    "sourceUri": "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/0.Global.Foundation/functions.ps1",
                    "destination": "C:\\AzureData\\functions.ps1"
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
                      "[concat('C:\\AzureData\\customize.ps1 -buildConfigEncoded ', base64(string(union(parameters('imageTemplate').build, createObject('binStorage', parameters('binStorage'))))))]"
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
              "publisher": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('computeGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionComputeGallery')).identifier.publisher]",
              "offer": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('computeGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionComputeGallery')).identifier.offer]",
              "sku": "[reference(resourceId('Microsoft.Compute/galleries/images', parameters('computeGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionComputeGallery')).identifier.sku]",
              "version": "[parameters('imageTemplates')[copyIndex()].image.inputVersion]"
            },
            "customize": "[if(equals(reference(resourceId('Microsoft.Compute/galleries/images', parameters('computeGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName), variables('apiVersionComputeGallery')).osType, 'Windows'), fx.GetCustomizeCommandsWindows(parameters('imageTemplates')[copyIndex()], parameters('binStorage')), fx.GetCustomizeCommandsLinux(parameters('imageTemplates')[copyIndex()], parameters('binStorage')))]",
            "buildTimeoutInMinutes": "[parameters('imageTemplates')[copyIndex()].build.timeoutMinutes]",
            "distribute": [
              {
                "type": "SharedImage",
                "runOutputName": "[concat(parameters('imageTemplates')[copyIndex()].name, '-', parameters('imageTemplates')[copyIndex()].build.outputVersion)]",
                "galleryImageId": "[resourceId('Microsoft.Compute/galleries/images/versions', parameters('computeGalleryName'), parameters('imageTemplates')[copyIndex()].image.definitionName, parameters('imageTemplates')[copyIndex()].build.outputVersion)]",
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

output "imageTemplates" {
  value = var.imageTemplates
}
