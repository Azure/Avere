#######################################################################################################
# Weka (https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) #
#######################################################################################################

variable "weka" {
  type = object(
    {
      name = object(
        {
          resource = string
          display  = string
        }
      )
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
          subnet = object(
            {
              range = string
              mask  = number
            }
          )
          enableAcceleration = bool
        }
      )
      objectTier = object(
        {
          percent = number
          storage = object(
            {
              accountName   = string
              accountKey    = string
              containerName = string
            }
          )
        }
      )
      fileSystem = object(
        {
          name         = string
          groupName    = string
          authRequired = bool
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
      dataProtection = object(
        {
          level       = number
          hotSpare    = number
          stripeWidth = number
        }
      )
      adminLogin = object(
        {
          userName     = string
          userPassword = string
          sshPublicKey = string
          passwordAuth = object(
            {
              disable = bool
            }
          )
        }
      )
      enableSupportCloud = bool
    }
  )
}

data "azurerm_virtual_machine_scale_set" "weka" {
  count               = local.wekaCount
  name                = azurerm_linux_virtual_machine_scale_set.weka[0].name
  resource_group_name = azurerm_linux_virtual_machine_scale_set.weka[0].resource_group_name
}

locals {
  wekaCount = var.weka.name.resource != "" ? 1 : 0
  wekaImage = {
    id = var.weka.machine.image.id
    plan = {
      publisher = var.weka.machine.image.plan.publisher != "" ? var.weka.machine.image.plan.publisher : try(lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].publisher), "")
      product   = var.weka.machine.image.plan.product != "" ? var.weka.machine.image.plan.product : try(lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].offer), "")
      name      = var.weka.machine.image.plan.name != "" ? var.weka.machine.image.plan.name : try(lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].sku), "")
    }
  }
  wekaObjectTier = merge(var.weka.objectTier, {
    storage = {
      accountName   = var.weka.objectTier.storage.accountName != "" ? var.weka.objectTier.storage.accountName : data.azurerm_storage_account.blob.name
      accountKey    = var.weka.objectTier.storage.accountKey != "" ? var.weka.objectTier.storage.accountKey : data.azurerm_storage_account.blob.secondary_access_key
      containerName = var.weka.objectTier.storage.containerName != "" ? var.weka.objectTier.storage.containerName : "weka"
    }
  })
  wekaNetworkSubnet = try(data.azurerm_subnet.storage_primary[0], data.azurerm_subnet.compute_storage)
  wekaMachineSize   = trimsuffix(trimsuffix(trimprefix(var.weka.machine.size, "Standard_"), "as_v3"), "s_v3")
  wekaContainerSize = local.wekaContainerSizes[local.wekaMachineSize]
  wekaContainerSizes = {
    L8 = <<-json
      '{
        "nvmeDisk"     : 1,
        "coreDrives"   : 1,
        "coreCompute"  : 1,
        "coreFrontend" : 1,
        "memory"       : "31GB"
      }'
    json
    L16 = <<-json
      '{
        "nvmeDisk"     : 2,
        "coreDrives"   : 2,
        "coreCompute"  : 4,
        "coreFrontend" : 1,
        "memory"       : "72GB"
      }'
    json
    L32 = <<-json
      '{
        "nvmeDisk"     : 4,
        "coreDrives"   : 2,
        "coreCompute"  : 4,
        "coreFrontend" : 1,
        "memory"       : "189GB"
      }'
    json
    L48 = <<-json
      '{
        "nvmeDisk"     : 6,
        "coreDrives"   : 3,
        "coreCompute"  : 3,
        "coreFrontend" : 1,
        "memory"       : "306GB"
      }'
    json
  }
  wekaStripWidth     = var.weka.dataProtection.stripeWidth >= 3 && var.weka.dataProtection.stripeWidth <= 16 ? var.weka.dataProtection.stripeWidth : var.weka.machine.count - var.weka.dataProtection.level - 1
  wekaDataProtection = merge(var.weka.dataProtection,
    {stripeWidth = local.wekaStripWidth < 16 ? local.wekaStripWidth : 16}
  )
}

resource "azurerm_resource_group" "weka" {
  count    = local.wekaCount
  name     = "${var.resourceGroupName}.Weka"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_proximity_placement_group" "weka" {
  count               = local.wekaCount
  name                = var.weka.name.resource
  resource_group_name = azurerm_resource_group.weka[0].name
  location            = azurerm_resource_group.weka[0].location
}

resource "azurerm_linux_virtual_machine_scale_set" "weka" {
  count                           = local.wekaCount
  name                            = var.weka.name.resource
  resource_group_name             = azurerm_resource_group.weka[0].name
  location                        = azurerm_resource_group.weka[0].location
  sku                             = var.weka.machine.size
  instances                       = var.weka.machine.count
  source_image_id                 = var.weka.machine.image.id
  admin_username                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : var.weka.adminLogin.userName
  admin_password                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.weka.adminLogin.userPassword
  disable_password_authentication = var.weka.adminLogin.passwordAuth.disable
  proximity_placement_group_id    = azurerm_proximity_placement_group.weka[0].id
  single_placement_group          = true
  overprovision                   = false
  network_interface {
    name    = "primary"
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = local.wekaNetworkSubnet.id
    }
    enable_accelerated_networking = var.weka.network.enableAcceleration
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
          {wekaVersion        = "4.1.0.77"},
          {wekaResourceName   = var.weka.name.resource},
          {wekaNetwork        = var.weka.network},
          {wekaMachineSize    = var.weka.machine.size},
          {wekaDataDiskSize   = var.weka.dataDisk.sizeGB},
          {wekaDataProtection = local.wekaDataProtection},
          {wekaContainerSize  = local.wekaContainerSize},
          {binStorageHost     = module.global.binStorage.host},
          {binStorageAuth     = module.global.binStorage.auth}
        ))
      )}"
    })
  }
  dynamic plan {
    for_each = local.wekaImage.plan.name != "" ? [1] : []
    content {
      publisher = local.wekaImage.plan.publisher
      product   = local.wekaImage.plan.product
      name      = local.wekaImage.plan.name
    }
  }
  dynamic admin_ssh_key {
    for_each = var.weka.adminLogin.sshPublicKey != "" ? [1] : []
    content {
      username   = var.weka.adminLogin.userName
      public_key = var.weka.adminLogin.sshPublicKey
    }
  }
}

resource "terraform_data" "weka" {
  count = local.wekaCount
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "weka cluster create ${azurerm_linux_virtual_machine_scale_set.weka[0].name}{000000..${format("%06d", var.weka.machine.count - 1)}} --admin-password ${var.weka.adminLogin.userPassword}",
      "weka user login admin ${var.weka.adminLogin.userPassword}",
      "weka cluster update --cluster-name='${var.weka.name.display}'",
      "weka cluster default-net set --range ${var.weka.network.subnet.range} --netmask-bits ${var.weka.network.subnet.mask}",
      "containerSize=${local.wekaContainerSize}",
      "coreCountDrives=$(echo $containerSize | jq -r .coreDrives)",
      "coreCountCompute=$(echo $containerSize | jq -r .coreCompute)",
      "coreCountFrontend=$(echo $containerSize | jq -r .coreFrontend)",
      "for (( i=0; i<${var.weka.machine.count}; i++ )); do",
      "  containerId=$i",
      "  containerSize=${local.wekaContainerSize}",
      "  nvmeDisk=$(echo $containerSize | jq -r .nvmeDisk)",
      "  clusterHost=${azurerm_linux_virtual_machine_scale_set.weka[0].name}$(printf %06d $i)",
      "  for (( d=0; d<$nvmeDisk; d++ )); do",
      "    weka cluster drive add $containerId --HOST $clusterHost /dev/nvme$(echo $d)n1",
      "  done",
      "  containerCores=$(($coreCountDrives + $coreCountCompute + $coreCountFrontend))",
      "  weka cluster container cores $containerId $containerCores",
      "done",
      "weka cluster container apply --all --force",
      "sleep 30s",
      "weka cluster update --data-drives ${local.wekaDataProtection.stripeWidth} --parity-drives ${local.wekaDataProtection.level}",
      "weka cluster hot-spare ${local.wekaDataProtection.hotSpare}",
      "weka cluster start-io",
      "ioStatus=$(weka status --json | jq -r .io_status)",
      "if [ \"$ioStatus\" == \"STARTED\" ]; then",
      "  fsName=${var.weka.fileSystem.name}",
      "  fsGroupName=${var.weka.fileSystem.groupName}",
      "  fsAuthRequired=${var.weka.fileSystem.authRequired ? "yes" : "no"}",
      "  fsContainerName=${local.wekaObjectTier.storage.containerName}",
      "  fsDriveBytes=$(weka status --json | jq -r .capacity.unprovisioned_bytes)",
      "  fsTotalBytes=$(($fsDriveBytes * 100 / (100 - ${local.wekaObjectTier.percent})))",
      "  weka fs tier s3 add $fsContainerName --obs-type AZURE --hostname ${local.wekaObjectTier.storage.accountName}.blob.core.windows.net --secret-key ${nonsensitive(local.wekaObjectTier.storage.accountKey)} --access-key-id ${local.wekaObjectTier.storage.accountName} --bucket ${local.wekaObjectTier.storage.containerName} --protocol https --port 443",
      "  weka fs group create $fsGroupName",
      "  weka fs create $fsName $fsGroupName \"$fsTotalBytes\"B --obs-name $fsContainerName --ssd-capacity \"$fsDriveBytes\"B --auth-required $fsAuthRequired",
      "fi",
      "if [ \"${var.weka.enableSupportCloud}\" == \"true\" ]; then",
      "  weka cloud enable",
      "fi",
      "weka status",
      "weka alerts"
    ]
  }
}

output "resourceGroupNameWeka" {
  value = local.wekaCount == 0 ? "" : azurerm_resource_group.weka[0].name
}
