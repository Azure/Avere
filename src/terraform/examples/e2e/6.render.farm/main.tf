terraform {
  required_version = ">= 1.3.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.41.0"
    }
  }
  backend "azurerm" {
    key = "6.render.farm"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine_scale_set {
      force_delete                  = false
      roll_instances_when_required  = true
      scale_to_zero_before_deletion = true
    }
  }
}

module "global" {
  source = "../0.global/module"
}

variable "resourceGroupName" {
  type = string
}

variable "virtualMachineScaleSets" {
  type = list(object(
    {
      name    = string
      imageId = string
      machine = object(
        {
          size  = string
          count = number
        }
      )
      network = object(
        {
          enableAcceleratedNetworking = bool
        }
      )
      operatingSystem = object(
        {
          type = string
          disk = object(
            {
              storageType = string
              cachingType = string
              ephemeral = object(
                {
                  enable    = bool
                  placement = string
                }
              )
            }
          )
        }
      )
      adminLogin = object(
        {
          userName            = string
          userPassword        = string
          sshPublicKey        = string
          disablePasswordAuth = bool
        }
      )
      customExtension = object(
        {
          enable   = bool
          fileName = string
          parameters = object(
            {
              fileSystemMountsStorage      = list(string)
              fileSystemMountsStorageCache = list(string)
              fileSystemMountsDeadline     = list(string)
              fileSystemPermissions        = list(string)
            }
          )
        }
      )
      monitorExtension = object(
        {
          enable = bool
        }
      )
      spot = object(
        {
          enable         = bool
          evictionPolicy = string
        }
      )
      terminationNotification = object(
        {
          enable                   = bool
          timeoutDelay             = string
          detectionIntervalSeconds = number
        }
      )
    }
  ))
}

variable "kubernetes" {
  type = object(
    {
      fleet = object(
        {
          name      = string
          dnsPrefix = string
        }
      )
      clusters = list(object(
        {
          name      = string
          dnsPrefix = string
          systemNodePool = object(
            {
              name = string
              machine = object(
                {
                  size  = string
                  count = number
                }
              )
            }
          )
          userNodePools = list(object(
            {
              name = string
              machine = object(
                {
                  size  = string
                  count = number
                }
              )
              spot = object(
                {
                  enable         = bool
                  evictionPolicy = string
                }
              )
            }
          ))
        }
      ))
    }
  )
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

data "azurerm_key_vault_secret" "admin_username" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.render[0].id
}

data "azurerm_key_vault_secret" "admin_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.render[0].id
}

data "azurerm_log_analytics_workspace" "monitor" {
  count               = module.global.monitorWorkspace.name != "" ? 1 : 0
  name                = module.global.monitorWorkspace.name
  resource_group_name = module.global.resourceGroupName
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

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName
    key                  = "4.image.builder"
  }
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

data "azurerm_private_dns_zone" "render" {
  name                = data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

locals {
  stateExistsNetwork      = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
  kubernetesUserNodePools = flatten([
    for kubernetesCluster in var.kubernetes.clusters : [
      for userNodePool in kubernetesCluster.userNodePools : {
        name               = userNodePool.name
        clusterName        = kubernetesCluster.name
        machineSize        = userNodePool.machine.size
        machineCount       = userNodePool.machine.count
        spotEnable         = userNodePool.spot.enable
        spotEvictionPolicy = userNodePool.spot.evictionPolicy
      }
    ] if kubernetesCluster.name != ""
  ])
}

resource "azurerm_resource_group" "farm" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_linux_virtual_machine_scale_set" "farm" {
  for_each = {
    for virtualMachineScaleSet in var.virtualMachineScaleSets : virtualMachineScaleSet.name => virtualMachineScaleSet if virtualMachineScaleSet.name != "" && virtualMachineScaleSet.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  source_image_id                 = each.value.imageId
  sku                             = each.value.machine.size
  instances                       = each.value.machine.count
  admin_username                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : each.value.adminLogin.userName
  admin_password                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  priority                        = each.value.spot.enable ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.enable ? each.value.spot.evictionPolicy : null
  single_placement_group          = false
  overprovision                   = false
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
    enable_accelerated_networking = each.value.network.enableAcceleratedNetworking
  }
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    dynamic diff_disk_settings {
      for_each = each.value.operatingSystem.disk.ephemeral.enable ? [1] : []
      content {
        option    = "Local"
        placement = each.value.operatingSystem.disk.ephemeral.placement
      }
    }
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.render.id
    ]
  }
  dynamic admin_ssh_key {
    for_each = each.value.adminLogin.sshPublicKey == "" ? [] : [1]
    content {
      username   = each.value.adminLogin.userName
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  dynamic extension {
    for_each = each.value.customExtension.fileName != "" ? [1] : []
    content {
      name                       = "Custom"
      type                       = "CustomScript"
      publisher                  = "Microsoft.Azure.Extensions"
      type_handler_version       = "2.1"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        "script": "${base64encode(
          templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters,
            { renderManager                                   = module.global.renderManager },
            { fileSystemMountsDelimiter                       = ";" },
            { terminationNotificationDetectionIntervalSeconds = each.value.terminationNotification.detectionIntervalSeconds }
          ))
        )}"
      })
    }
  }
  dynamic extension {
    for_each = each.value.monitorExtension.enable && module.global.monitorWorkspace.name != "" ? [1] : []
    content {
      name                       = "Monitor"
      type                       = "AzureMonitorLinuxAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type_handler_version       = "1.21"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        "workspaceId": data.azurerm_log_analytics_workspace.monitor[0].workspace_id
      })
      protected_settings = jsonencode({
        "workspaceKey": data.azurerm_log_analytics_workspace.monitor[0].primary_shared_key
      })
    }
  }
  dynamic termination_notification {
    for_each = each.value.terminationNotification.enable ? [1] : []
    content {
      enabled = each.value.terminationNotification.enable
      timeout = each.value.terminationNotification.timeoutDelay
    }
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "farm" {
  for_each = {
    for virtualMachineScaleSet in var.virtualMachineScaleSets : virtualMachineScaleSet.name => virtualMachineScaleSet if virtualMachineScaleSet.name != "" && virtualMachineScaleSet.operatingSystem.type == "Windows"
  }
  name                   = each.value.name
  resource_group_name    = azurerm_resource_group.farm.name
  location               = azurerm_resource_group.farm.location
  source_image_id        = each.value.imageId
  sku                    = each.value.machine.size
  instances              = each.value.machine.count
  admin_username         = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : each.value.adminLogin.userName
  admin_password         = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
  priority               = each.value.spot.enable ? "Spot" : "Regular"
  eviction_policy        = each.value.spot.enable ? each.value.spot.evictionPolicy : null
  single_placement_group = false
  overprovision          = false
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
    enable_accelerated_networking = each.value.network.enableAcceleratedNetworking
  }
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    dynamic diff_disk_settings {
      for_each = each.value.operatingSystem.disk.ephemeral.enable ? [1] : []
      content {
        option    = "Local"
        placement = each.value.operatingSystem.disk.ephemeral.placement
      }
    }
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.render.id
    ]
  }
  dynamic extension {
    for_each = each.value.customExtension.enable ? [1] : []
    content {
      name                       = "Custom"
      type                       = "CustomScriptExtension"
      publisher                  = "Microsoft.Compute"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        "commandToExecute": "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
          templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters,
            { renderManager                                   = module.global.renderManager },
            { fileSystemMountsDelimiter                       = ";" },
            { terminationNotificationDetectionIntervalSeconds = each.value.terminationNotification.detectionIntervalSeconds }
          )), "UTF-16LE"
        )}"
      })
    }
  }
  dynamic extension {
    for_each = each.value.monitorExtension.enable && module.global.monitorWorkspace.name != "" ? [1] : []
    content {
      name                       = "Monitor"
      type                       = "AzureMonitorWindowsAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type_handler_version       = "1.7"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        "workspaceId": data.azurerm_log_analytics_workspace.monitor[0].workspace_id
      })
      protected_settings = jsonencode({
        "workspaceKey": data.azurerm_log_analytics_workspace.monitor[0].primary_shared_key
      })
    }
  }
  dynamic termination_notification {
    for_each = each.value.terminationNotification.enable ? [1] : []
    content {
      enabled = each.value.terminationNotification.enable
      timeout = each.value.terminationNotification.timeoutDelay
    }
  }
}

#######################################################################
# Kubernetes (https://learn.microsoft.com/azure/aks/intro-kubernetes) #
#######################################################################

resource "azurerm_kubernetes_fleet_manager" "farm" {
  count               = var.kubernetes.fleet.name != "" ? 1 : 0
  name                = var.kubernetes.fleet.name
  resource_group_name = azurerm_resource_group.farm.name
  location            = azurerm_resource_group.farm.location
  hub_profile {
    dns_prefix = var.kubernetes.fleet.dnsPrefix == "" ? var.kubernetes.fleet.name : var.kubernetes.fleet.dnsPrefix
  }
}

resource "azurerm_kubernetes_cluster" "farm" {
  for_each = {
    for kubernetesCluster in var.kubernetes.clusters : kubernetesCluster.name => kubernetesCluster if kubernetesCluster.name != ""
  }
  name                    = each.value.name
  resource_group_name     = azurerm_resource_group.farm.name
  location                = azurerm_resource_group.farm.location
  dns_prefix              = each.value.dnsPrefix == "" ? "render" : each.value.dnsPrefix
  private_cluster_enabled = true
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.render.id
    ]
  }
  default_node_pool {
    name                         = each.value.systemNodePool.name
    vm_size                      = each.value.systemNodePool.machine.size
    node_count                   = each.value.systemNodePool.machine.count
    vnet_subnet_id               = data.azurerm_subnet.farm.id
    only_critical_addons_enabled = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "farm" {
  for_each = {
    for userNodePool in local.kubernetesUserNodePools : "${userNodePool.clusterName}.${userNodePool.name}" => userNodePool
  }
  name                  = each.value.name
  kubernetes_cluster_id = "${azurerm_resource_group.farm.id}/providers/Microsoft.ContainerService/managedClusters/${each.value.clusterName}"
  vm_size               = each.value.machineSize
  node_count            = each.value.machineCount
  priority              = each.value.spotEnable ? "Spot" : "Regular"
  eviction_policy       = each.value.spotEnable ? each.value.spotEvictionPolicy : null
  depends_on = [
    azurerm_kubernetes_cluster.farm
  ]
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualMachineScaleSets" {
  value = var.virtualMachineScaleSets
}

output "kubernetes" {
  value = var.kubernetes
}
