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
          enableAcceleration = bool
        }
      )
      terminateNotification = object(
        {
          enable       = bool
          delayTimeout = string
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
      healthExtension = object(
        {
          enable      = bool
          protocol    = string
          port        = number
          requestPath = string
        }
      )
      license = object(
        {
          key = string
          payg = object(
            {
              planId    = string
              secretKey = string
            }
          )
        }
      )
      supportUrl = string
    }
  )
}

data "azurerm_storage_account" "blob" {
  count               = var.weka.name.resource != "" ? 1 : 0
  name                = local.blobStorageAccount.name
  resource_group_name = azurerm_resource_group.storage.name
  depends_on = [
    azurerm_storage_account.storage
  ]
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
      accountName   = var.weka.objectTier.storage.accountName != "" ? var.weka.objectTier.storage.accountName : try(data.azurerm_storage_account.blob[0].name, "")
      accountKey    = var.weka.objectTier.storage.accountKey != "" ? var.weka.objectTier.storage.accountKey : try(data.azurerm_storage_account.blob[0].secondary_access_key, "")
      containerName = var.weka.objectTier.storage.containerName != "" ? var.weka.objectTier.storage.containerName : "weka"
    }
  })
  wekaMachineSize  = trimsuffix(trimsuffix(trimprefix(var.weka.machine.size, "Standard_"), "as_v3"), "s_v3")
  wekaMachineSpec  = local.wekaMachineSpecs[local.wekaMachineSize]
  wekaMachineSpecs = {
    L8 = <<-json
      '{
        "nvmeDisk"         : 1,
        "coreDrives"       : 1,
        "coreCompute"      : 1,
        "coreFrontend"     : 1,
        "networkInterface" : 4,
        "computeMemory"    : "31GB"
      }'
    json
    L16 = <<-json
      '{
        "nvmeDisk"         : 2,
        "coreDrives"       : 2,
        "coreCompute"      : 4,
        "coreFrontend"     : 1,
        "networkInterface" : 8,
        "computeMemory"    : "72GB"
      }'
    json
    L32 = <<-json
      '{
        "nvmeDisk"         : 4,
        "coreDrives"       : 2,
        "coreCompute"      : 4,
        "coreFrontend"     : 1,
        "networkInterface" : 8,
        "computeMemory"    : "189GB"
      }'
    json
    L48 = <<-json
      '{
        "nvmeDisk"         : 6,
        "coreDrives"       : 3,
        "coreCompute"      : 3,
        "coreFrontend"     : 1,
        "networkInterface" : 8,
        "computeMemory"    : "306GB"
      }'
    json
    L64 = <<-json
      '{
        "nvmeDisk"         : 8,
        "coreDrives"       : 2,
        "coreCompute"      : 4,
        "coreFrontend"     : 1,
        "networkInterface" : 8,
        "computeMemory"    : "418GB"
      }'
    json
  }
  wekaCoreIdsScript    = "/usr/local/bin/weka-core-ids.sh"
  wekaFileSystemScript = "/usr/local/bin/weka-file-system.sh"
}

resource "azurerm_resource_group" "weka" {
  count    = var.weka.name.resource != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Weka"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_role_assignment" "weka_virtual_machine_contributor" {
  count                = var.weka.name.resource != "" ? 1 : 0
  role_definition_name = "Virtual Machine Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = azurerm_resource_group.weka[0].id
}

resource "azurerm_role_assignment" "weka_private_dns_zone_contributor" {
  count                = var.weka.name.resource != "" ? 1 : 0
  role_definition_name = "Private DNS Zone Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#private-dns-zone-contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = data.azurerm_resource_group.network.id
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
  custom_data                     = base64encode(templatefile("terminate.sh", {
    wekaClusterName      = var.weka.name.resource
    wekaAdminPassword    = var.weka.adminLogin.userPassword
    wekaFileSystemScript = local.wekaFileSystemScript
    dnsResourceGroupName = data.azurerm_private_dns_zone.network.resource_group_name
    dnsZoneName          = data.azurerm_private_dns_zone.network.name
    dnsRecordSetName     = local.privateDnsRecordSetName
  }))
  network_interface {
    name    = "nic1"
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = local.virtualNetworkSubnet.id
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
  termination_notification {
    enabled = var.weka.terminateNotification.enable
    timeout = var.weka.terminateNotification.delayTimeout
  }
  extension {
    name                       = "Initialize"
    type                       = "CustomScript"
    publisher                  = "Microsoft.Azure.Extensions"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true
    settings = jsonencode({
      script = "${base64encode(
        templatefile("initialize.sh", {
          wekaVersion               = "4.1.0.77"
          wekaClusterName           = var.weka.name.resource
          wekaDataDiskSize          = var.weka.dataDisk.sizeGB
          wekaMachineSpec           = local.wekaMachineSpec
          wekaCoreIdsScript         = local.wekaCoreIdsScript
          wekaFileSystemName        = var.weka.fileSystem.name
          wekaFileSystemScript      = local.wekaFileSystemScript
          wekaObjectTierPercent     = local.wekaObjectTier.percent
          wekaResourceGroupName     = azurerm_resource_group.weka[0].name
          wekaVMScaleSetName        = var.weka.name.resource
          wekaTerminateNotification = var.weka.terminateNotification
          wekaAdminPassword         = var.weka.adminLogin.userPassword
          dnsResourceGroupName      = data.azurerm_private_dns_zone.network.resource_group_name
          dnsZoneName               = data.azurerm_private_dns_zone.network.name
          dnsRecordSetName          = local.privateDnsRecordSetName
          binStorageHost            = module.global.binStorage.host
          binStorageAuth            = module.global.binStorage.auth
        })
      )}"
    })
  }
  dynamic extension {
    for_each = var.weka.healthExtension.enable ? [1] : []
    content {
      name                       = "Health"
      type                       = "ApplicationHealthLinux"
      publisher                  = "Microsoft.ManagedServices"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        protocol    = var.weka.healthExtension.protocol
        port        = var.weka.healthExtension.port
        requestPath = var.weka.healthExtension.requestPath
      })
    }
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
  depends_on = [
    azurerm_role_assignment.weka_virtual_machine_contributor,
    azurerm_role_assignment.weka_private_dns_zone_contributor
  ]
}

resource "azurerm_private_dns_a_record" "data" {
  count               = var.weka.name.resource != "" ? 1 : 0
  name                = local.privateDnsRecordSetName
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  records             = [for vmInstance in data.azurerm_virtual_machine_scale_set.weka[0].instances : vmInstance.private_ip_address]
  ttl                 = 300
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
      "machineSpec=${local.wekaMachineSpec}",
      "nvmeDisks=/dev/nvme0n1",
      "for (( d=1; d<$(echo $machineSpec | jq -r .nvmeDisk); d++ )); do",
      "  nvmeDisks=\"$nvmeDisks /dev/nvme$(echo $d)n1\"",
      "done",
      "weka cluster create ${join(" ", data.azurerm_virtual_machine_scale_set.weka[0].instances[*].private_ip_address)} --admin-password ${var.weka.adminLogin.userPassword} &> weka-cluster-create.log",
      "weka user login admin ${var.weka.adminLogin.userPassword}",
      "for (( i=0; i<${var.weka.machine.count}; i++ )); do",
      "  hostName=${azurerm_linux_virtual_machine_scale_set.weka[0].name}$(printf %06X $i)",
      "  weka cluster drive add $i --HOST $hostName $nvmeDisks",
      "done"
    ]
  }
}

resource "terraform_data" "weka_container_setup" {
  count = var.weka.name.resource != "" ? var.weka.machine.count : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[count.index].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "failureDomain=$(hostname)",
      "machineSpec=${local.wekaMachineSpec}",
      "source ${local.wekaCoreIdsScript}",
      "joinIps=${join(",", [for vmInstance in data.azurerm_virtual_machine_scale_set.weka[0].instances : vmInstance.private_ip_address])}",
      "sudo weka local setup container --name compute0 --base-port 15000 --failure-domain $failureDomain --join-ips $joinIps --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $computeMemory --no-frontends &> weka-container-compute0.log",
      "sudo weka local setup container --name frontend0 --base-port 16000 --failure-domain $failureDomain --join-ips $joinIps --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate &> weka-container-frontend0.log"
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
      "weka cloud enable ${var.weka.supportUrl != "" ? "--cloud-url=${var.weka.supportUrl}" : ""}",
      "if [ \"${var.weka.license.key}\" != \"\" ]; then",
      "  weka cluster license set ${var.weka.license.key} &> weka-cluster-license.log",
      "elif [ \"${var.weka.license.payg.planId}\" != \"\" ]; then",
      "  weka cluster license payg ${var.weka.license.payg.planId} ${var.weka.license.payg.secretKey} &> weka-cluster-license.log",
      "fi",
      "weka cluster start-io &> weka-cluster-start.log"
    ]
  }
  depends_on = [
    terraform_data.weka_container_setup
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
      "  source ${local.wekaFileSystemScript}",
      "  fsGroupName=${var.weka.fileSystem.groupName}",
      "  fsAuthRequired=${var.weka.fileSystem.authRequired ? "yes" : "no"}",
      "  fsContainerName=${local.wekaObjectTier.storage.containerName}",
      "  weka fs tier s3 add $fsContainerName --obs-type AZURE --hostname ${local.wekaObjectTier.storage.accountName}.blob.core.windows.net --secret-key ${nonsensitive(local.wekaObjectTier.storage.accountKey)} --access-key-id ${local.wekaObjectTier.storage.accountName} --bucket ${local.wekaObjectTier.storage.containerName} --protocol https --port 443 &> weka-fs-tier.log",
      "  weka fs group create $fsGroupName &> weka-fs-group-create.log",
      "  weka fs create $fsName $fsGroupName \"$fsTotalCapacityBytes\"B --obs-name $fsContainerName --ssd-capacity \"$fsDriveCapacityBytes\"B --auth-required $fsAuthRequired &> weka-fs-create.log",
      "fi",
      "weka status"
    ]
  }
  depends_on = [
    azurerm_storage_container.core,
    terraform_data.weka_cluster_start
  ]
}

resource "terraform_data" "weka_data" {
  count = var.weka.name.resource != "" && var.dataLoadSource.accountName != "" ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "sudo weka agent install-agent",
      "mountPath=/mnt/${var.dataLoadSource.containerName}",
      "sudo mkdir -p $mountPath",
      "sudo mount -t wekafs ${var.weka.fileSystem.name} $mountPath",
      "if [ \"${var.dataLoadSource.blobName}\" != \"\" ]; then",
      "  sudo az storage copy --source-account-name ${var.dataLoadSource.accountName} --source-account-key ${var.dataLoadSource.accountKey} --source-container ${var.dataLoadSource.containerName} --source-blob ${var.dataLoadSource.blobName} --recursive --destination /mnt/${var.dataLoadSource.containerName}/${var.dataLoadSource.blobName}",
      "else",
      "  sudo az storage copy --source-account-name ${var.dataLoadSource.accountName} --source-account-key ${var.dataLoadSource.accountKey} --source-container ${var.dataLoadSource.containerName} --recursive --destination /mnt",
      "fi"
    ]
  }
  depends_on = [
    terraform_data.weka_file_system
  ]
}

output "resourceGroupNameWeka" {
  value = var.weka.name.resource != "" ? azurerm_resource_group.weka[0].name : ""
}
