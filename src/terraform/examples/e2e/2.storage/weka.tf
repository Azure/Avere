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
          stripeWidth = number
          parityLevel = number
          hotSpare    = number
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
      supportCloudUrl = string
      classicLicense  = string
    }
  )
}

data "azurerm_virtual_machine_scale_set" "weka" {
  count               = var.weka.name.resource != "" ? 1 : 0
  name                = azurerm_linux_virtual_machine_scale_set.weka[0].name
  resource_group_name = azurerm_linux_virtual_machine_scale_set.weka[0].resource_group_name
}

locals {
  wekaImage = merge(var.weka.machine.image, {
    plan = {
      publisher = lower(var.weka.machine.image.plan.publisher != "" ? var.weka.machine.image.plan.publisher : try(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].publisher, ""))
      product   = lower(var.weka.machine.image.plan.product != "" ? var.weka.machine.image.plan.product : try(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].offer, ""))
      name      = lower(var.weka.machine.image.plan.name != "" ? var.weka.machine.image.plan.name : try(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].sku, ""))
    }
  })
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
  wekaCoreIdsScript = "weka-core-ids.sh"
}

resource "azurerm_resource_group" "weka" {
  count    = var.weka.name.resource != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Weka"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_proximity_placement_group" "weka" {
  count               = var.weka.name.resource != "" ? 1 : 0
  name                = var.weka.name.resource
  resource_group_name = azurerm_resource_group.weka[0].name
  location            = azurerm_resource_group.weka[0].location
}

resource "azurerm_linux_virtual_machine_scale_set" "weka" {
  count                           = var.weka.name.resource != "" ? 1 : 0
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
  single_placement_group          = false
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
          {wekaVersion       = "4.1.0.77"},
          {wekaResourceName  = var.weka.name.resource},
          {wekaDataDiskSize  = var.weka.dataDisk.sizeGB},
          {wekaContainerSize = local.wekaContainerSize},
          {wekaCoreIdsScript = local.wekaCoreIdsScript},
          {binStorageHost    = module.global.binStorage.host},
          {binStorageAuth    = module.global.binStorage.auth}
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

resource "terraform_data" "weka_cluster_create" {
  count = var.weka.name.resource != "" ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "containerSize=${local.wekaContainerSize}",
      "source /usr/local/bin/${local.wekaCoreIdsScript}",
      "weka cluster create ${azurerm_linux_virtual_machine_scale_set.weka[0].name}{000000..${format("%06d", var.weka.machine.count - 1)}} --admin-password ${var.weka.adminLogin.userPassword}",
      "weka user login admin ${var.weka.adminLogin.userPassword}",
      "weka cluster default-net set --range ${var.weka.network.subnet.range} --netmask-bits ${var.weka.network.subnet.mask}",
      "for (( i=0; i<${var.weka.machine.count}; i++ )); do",
      "  containerId=$i",
      "  containerSize=${local.wekaContainerSize}",
      "  nvmeDisk=$(echo $containerSize | jq -r .nvmeDisk)",
      "  hostName=${azurerm_linux_virtual_machine_scale_set.weka[0].name}$(printf %06d $i)",
      "  for (( d=0; d<$nvmeDisk; d++ )); do",
      "    weka cluster drive add $containerId --HOST $hostName /dev/nvme$(echo $d)n1",
      "  done",
      "  weka cluster container cores $containerId $(($coreCountDrives + $coreCountCompute + $coreCountFrontend)) --drives-dedicated-cores $coreCountDrives --compute-dedicated-cores $coreCountCompute --frontend-dedicated-cores $coreCountFrontend",
      "done",
      "weka cluster container apply --all --force",
      "sleep 30s",
    ]
  }
}

resource "terraform_data" "weka_container_compute" {
  count = var.weka.name.resource != "" ? var.weka.machine.count : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[count.index].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "containerSize=${local.wekaContainerSize}",
      "source /usr/local/bin/${local.wekaCoreIdsScript}",
      #"sudo weka local setup container --name compute --base-port 15000 --join-ips $(hostname -i) --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $memory --no-frontends"
      "sudo weka local setup container --name compute --base-port 15000 --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $memory --no-frontends"
    ]
  }
  depends_on = [
    terraform_data.weka_cluster_create
  ]
}

resource "terraform_data" "weka_cluster_start" {
  count = var.weka.name.resource != "" ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "weka cluster update --cluster-name='${var.weka.name.display}' --data-drives ${var.weka.dataProtection.stripeWidth} --parity-drives ${var.weka.dataProtection.parityLevel}",
      "weka cluster hot-spare ${var.weka.dataProtection.hotSpare}",
      "weka cloud enable ${var.weka.supportCloudUrl != "" ? "--cloud-url=${var.weka.supportCloudUrl}" : ""}",
      "if [ \"${var.weka.classicLicense}\" != \"\" ]; then",
      "  weka cluster license set ${var.weka.classicLicense}",
      "fi",
      "weka cluster start-io",
    ]
  }
  depends_on = [
    terraform_data.weka_container_compute
  ]
}

resource "terraform_data" "weka_container_frontend" {
  count = var.weka.name.resource != "" ? var.weka.machine.count : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[count.index].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "containerSize=${local.wekaContainerSize}",
      "source /usr/local/bin/${local.wekaCoreIdsScript}",
      "sudo weka local setup container --name frontend --base-port 16000 --join-ips $(hostname -i) --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate"
    ]
  }
  depends_on = [
    terraform_data.weka_cluster_start
  ]
}

resource "terraform_data" "weka_file_system" {
  count = var.weka.name.resource != "" ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
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
      "weka status",
      "weka alerts"
    ]
  }
  depends_on = [
    terraform_data.weka_container_frontend
  ]
}

output "resourceGroupNameWeka" {
  value = var.weka.name.resource != "" ? azurerm_resource_group.weka[0].name : ""
}
