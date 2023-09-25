#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

variable "imageTemplates" {
  type = list(object(
    {
      name = string
      source = object(
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

locals {
  targetRegions = [
    for regionName in module.global.regionNames : {
      name               = regionName
      replicaCount       = 1
      storageAccountType = "Standard_LRS"
    }
  ]
}

resource "azurerm_role_assignment" "managed_identity_operator" {
  role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = data.azurerm_user_assigned_identity.studio.id
}

resource "azurerm_role_assignment" "contributor" {
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = azurerm_resource_group.image.id
}

resource "azapi_resource" "image_builder" {
  for_each = {
    for imageTemplate in var.imageTemplates : imageTemplate.name => imageTemplate
  }
  name      = each.value.name
  type      = "Microsoft.VirtualMachineImages/imageTemplates@2022-07-01"
  parent_id = azurerm_resource_group.image.id
  location  = azurerm_resource_group.image.location
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  body = jsonencode({
    properties = {
      buildTimeoutInMinutes = each.value.build.timeoutMinutes
      vmProfile = {
        vmSize       = each.value.build.machineSize
        osDiskSizeGB = each.value.build.osDiskSizeGB
        userAssignedIdentities = [
          data.azurerm_user_assigned_identity.studio.id
        ]
      }
      source = {
        type      = "PlatformImage"
        publisher = var.computeGallery.imageDefinition[each.value.source.definitionName].publisher
        offer     = var.computeGallery.imageDefinition[each.value.source.definitionName].offer
        sku       = var.computeGallery.imageDefinition[each.value.source.definitionName].sku
        version   = each.value.source.inputVersion
      }
      optimize = {
        vmBoot = {
          state = "Enabled"
        }
      }
      customize = each.value.source.definitionName == "Linux" ? [
        {
          type = "Shell"
          inline = [
            "hostname ${each.value.name}"
          ]
        },
        {
          type = "Shell"
          inline = [
            ":"
          ]
        },
        {
          type        = "File"
          sourceUri   = "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/0.Global.Foundation/functions.sh"
          destination = "/tmp/functions.sh"
        },
        {
          type        = "File"
          sourceUri   = "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/customize.sh"
          destination = "/tmp/customize.sh"
        },
        {
          type        = "File"
          sourceUri   = "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/terminate.sh"
          destination = "/tmp/terminate.sh"
        },
        {
          type = "Shell"
          inline = [
            "cat /tmp/customize.sh | tr -d \r | buildConfigEncoded=${base64encode(jsonencode(merge(each.value.build, {binStorage = var.binStorage})))} /bin/bash"
          ]
          runElevated = false
          runAsSystem = false
        }
      ] : [
        {
          type = "PowerShell"
          inline = [
            "Rename-Computer -NewName ${each.value.name}"
          ]
        },
        {
          type   = "WindowsRestart"
          inline = null
        },
        {
          type        = "File"
          sourceUri   = "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/0.Global.Foundation/functions.ps1"
          destination = "C:\\AzureData\\functions.ps1"
        },
        {
          type        = "File"
          sourceUri   = "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/customize.ps1"
          destination = "C:\\AzureData\\customize.ps1"
        },
        {
          type        = "File"
          sourceUri   = "https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/e2e/2.Image.Builder/terminate.ps1"
          destination = "C:\\AzureData\\terminate.ps1"
        },
        {
          type = "PowerShell"
          inline = [
            "C:\\AzureData\\customize.ps1 -buildConfigEncoded ${base64encode(jsonencode(merge(each.value.build, {binStorage = var.binStorage})))}"
          ]
          runElevated = true
          runAsSystem = true
        }
      ]
      distribute = [
        {
          type           = "SharedImage"
          runOutputName  = "${each.value.name}-${each.value.build.outputVersion}"
          galleryImageId = "${azurerm_shared_image.studio[each.value.source.definitionName].id}/versions/${each.value.build.outputVersion}"
          versioning = {
            scheme = "Latest"
            major  = tonumber(split(".", each.value.build.outputVersion)[0])
          }
          targetRegions = local.targetRegions
          artifactTags = {
            imageTemplateName = each.value.name
          }
        }
      ]
    }
  })
  schema_validation_enabled = false
  depends_on = [
    azurerm_role_assignment.managed_identity_operator,
    azurerm_role_assignment.contributor
  ]
}

output "imageTemplates" {
  value = var.imageTemplates
}
