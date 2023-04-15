#######################################################################################################
# Weka (https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) #
#######################################################################################################

variable "weka" {
  type = object(
    {
      clusterName = string
      machine = object(
        {
          size  = string
          count = number
          image = object(
            {
              id = string
              plan = object(
                {
                  publisher = string
                  product   = string
                  name      = string
                }
              )
            }
          )
        }
      )
      network = object(
        {
          enableAcceleratedNetworking = bool
        }
      )
      osDisk = object(
        {
          storageType = string
          cachingType = string
        }
      )
      dataDisk = object(
        {
          storageType = string
          cachingType = string
          sizeGB      = number
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
    }
  )
}

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "4.image.builder"
  }
}

data "azurerm_virtual_machine_scale_set" "weka" {
  count               = var.weka.clusterName != "" ? 1 : 0
  name                = azurerm_linux_virtual_machine_scale_set.weka[0].name
  resource_group_name = azurerm_linux_virtual_machine_scale_set.weka[0].resource_group_name
}

locals {
  weka = merge(var.weka, {
    machine = {
      size  = var.weka.machine.size
      count = var.weka.machine.count
      image = {
        id = var.weka.machine.image.id
        plan = {
          publisher = var.weka.machine.image.plan.publisher != "" ? var.weka.machine.image.plan.publisher : try(lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].publisher), "")
          product   = var.weka.machine.image.plan.product != "" ? var.weka.machine.image.plan.product : try(lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].offer), "")
          name      = var.weka.machine.image.plan.name != "" ? var.weka.machine.image.plan.name : try(lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].sku), "")
        }
      }
    }
  })
}

resource "azurerm_resource_group" "weka" {
  count    = var.weka.clusterName != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Weka"
  location = azurerm_resource_group.storage.location
}

# resource "azurerm_proximity_placement_group" "weka" {
#   count               = var.weka.clusterName != "" ? 1 : 0
#   name                = var.weka.clusterName
#   resource_group_name = azurerm_resource_group.weka[0].name
#   location            = azurerm_resource_group.weka[0].location
# }

resource "azurerm_linux_virtual_machine_scale_set" "weka" {
  count                           = var.weka.clusterName != "" ? 1 : 0
  name                            = var.weka.clusterName
  resource_group_name             = azurerm_resource_group.weka[0].name
  location                        = azurerm_resource_group.weka[0].location
  sku                             = var.weka.machine.size
  instances                       = var.weka.machine.count
  source_image_id                 = var.weka.machine.image.id
  admin_username                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : var.weka.adminLogin.userName
  admin_password                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.weka.adminLogin.userPassword
  disable_password_authentication = var.weka.adminLogin.disablePasswordAuth
  # proximity_placement_group_id    = azurerm_proximity_placement_group.weka[0].id
  single_placement_group          = true
  overprovision                   = false
  network_interface {
    name    = "primary"
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = try(data.azurerm_subnet.storage_primary[0].id, data.azurerm_subnet.compute_storage.id)
    }
    enable_accelerated_networking = var.weka.network.enableAcceleratedNetworking
  }
  os_disk {
    storage_account_type = var.weka.osDisk.storageType
    caching              = var.weka.osDisk.cachingType
  }
  data_disk {
    storage_account_type = var.weka.dataDisk.storageType
    caching              = var.weka.dataDisk.cachingType
    disk_size_gb         = var.weka.dataDisk.sizeGB
    create_option        = "Empty"
    lun                  = 0
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  extension {
    name                       = "Initialize"
    type                       = "CustomScript"
    publisher                  = "Microsoft.Azure.Extensions"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true
    settings = jsonencode({
      "script": "${base64encode(
        templatefile("initialize.sh", merge(
          { binStorageHost   = module.global.binStorage.host },
          { binStorageAuth   = module.global.binStorage.auth },
          { wekaClusterName  = var.weka.clusterName },
          { wekaDataDiskSize = var.weka.dataDisk.sizeGB }
        ))
      )}"
    })
  }
  dynamic plan {
    for_each = local.weka.machine.image.plan.name == "" ? [] : [1]
    content {
      publisher = local.weka.machine.image.plan.publisher
      product   = local.weka.machine.image.plan.product
      name      = local.weka.machine.image.plan.name
    }
  }
  dynamic admin_ssh_key {
    for_each = var.weka.adminLogin.sshPublicKey == "" ? [] : [1]
    content {
      username   = var.weka.adminLogin.userName
      public_key = var.weka.adminLogin.sshPublicKey
    }
  }
}

resource "terraform_data" "weka" {
  count = var.weka.clusterName != "" ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "pwd"
    ]
  }
}

output "resourceGroupNameWeka" {
  value = var.weka.clusterName == "" ? "" : azurerm_resource_group.weka[0].name
}
