#######################################################################################################
# Weka (https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) #
#######################################################################################################

variable "weka" {
  type = object(
    {
      enable   = bool
      apiToken = string
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
                  enable    = bool
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
          privateDnsZone = object(
            {
              recordSetName    = string
              recordTtlSeconds = number
            }
          )
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
          enable  = bool
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
          autoScale    = bool
          authRequired = bool
          loadFiles    = bool
        }
      )
      osDisk = object(
        {
          storageType = string
          cachingType = string
          sizeGB      = number
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
      healthExtension = object(
        {
          enable      = bool
          protocol    = string
          port        = number
          requestPath = string
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
      license = object(
        {
          key = string
          payGo = object(
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
  count               = var.weka.enable ? 1 : 0
  name                = local.blobStorageAccounts[0].name
  resource_group_name = azurerm_resource_group.storage.name
  depends_on = [
    azurerm_storage_account.storage
  ]
}

data "azurerm_virtual_machine_scale_set" "weka" {
  count               = var.weka.enable ? 1 : 0
  name                = azurerm_linux_virtual_machine_scale_set.weka[0].name
  resource_group_name = azurerm_linux_virtual_machine_scale_set.weka[0].resource_group_name
}

locals {
  weka = merge(
    {
      adminLogin = {
        userName = var.weka.adminLogin.userName != "" ? var.weka.adminLogin.userName : try(data.azurerm_key_vault_secret.admin_username[0].value, "")
        userPassword = var.weka.adminLogin.userPassword != "" ? var.weka.adminLogin.userPassword : try(data.azurerm_key_vault_secret.admin_password[0].value, "")
      }
    },
    var.weka
  )
  wekaObjectTier = merge(var.weka.objectTier, {
    storage = {
      accountName   = var.weka.objectTier.storage.accountName != "" ? var.weka.objectTier.storage.accountName : try(data.azurerm_storage_account.blob[0].name, "")
      accountKey    = var.weka.objectTier.storage.accountKey != "" ? var.weka.objectTier.storage.accountKey : try(data.azurerm_storage_account.blob[0].primary_access_key, "")
      containerName = var.weka.objectTier.storage.containerName != "" ? var.weka.objectTier.storage.containerName : "weka"
    }
  })
  wekaMachineSize = trimsuffix(trimsuffix(trimprefix(var.weka.machine.size, "Standard_"), "as_v3"), "s_v3")
  wekaMachineSpec = jsonencode(local.wekaMachineSpecs[local.wekaMachineSize])
  wekaMachineSpecs = {
    L8 = {
      nvmeDisks     = 1
      coreDrives    = 1
      coreCompute   = 1
      coreFrontend  = 1
      networkCards  = 4
      computeMemory = "31GB"
    }
    L16 = {
      nvmeDisks     = 2
      coreDrives    = 2
      coreCompute   = 4
      coreFrontend  = 1
      networkCards  = 8
      computeMemory = "72GB"
    }
    L32 = {
      nvmeDisks     = 4
      coreDrives    = 2
      coreCompute   = 4
      coreFrontend  = 1
      networkCards  = 8
      computeMemory = "189GB"
    }
    L48 = {
      nvmeDisks     = 6
      coreDrives    = 3
      coreCompute   = 3
      coreFrontend  = 1
      networkCards  = 8
      computeMemory = "306GB"
    }
    L64 = {
      nvmeDisks     = 8
      coreDrives    = 2
      coreCompute   = 4
      coreFrontend  = 1
      networkCards  = 8
      computeMemory = "418GB"
    }
  }
  wekaCoreIdsScript    = "${local.binDirectory}/weka-core-ids.sh"
  wekaDriveDisksScript = "${local.binDirectory}/weka-drive-disks.sh"
  wekaFileSystemScript = "${local.binDirectory}/weka-file-system.sh"
}

resource "azurerm_resource_group" "weka" {
  count    = var.weka.enable ? 1 : 0
  name     = "${var.resourceGroupName}.Weka"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_role_assignment" "weka_virtual_machine_contributor" {
  count                = var.weka.enable ? 1 : 0
  role_definition_name = "Virtual Machine Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = azurerm_resource_group.weka[0].id
}

resource "azurerm_role_assignment" "weka_private_dns_zone_contributor" {
  count                = var.weka.enable ? 1 : 0
  role_definition_name = "Private DNS Zone Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#private-dns-zone-contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = data.azurerm_resource_group.network.id
}

resource "azurerm_proximity_placement_group" "weka" {
  count               = var.weka.enable ? 1 : 0
  name                = var.weka.name.resource
  resource_group_name = azurerm_resource_group.weka[0].name
  location            = azurerm_resource_group.weka[0].location
}

resource "azurerm_linux_virtual_machine_scale_set" "weka" {
  count                           = var.weka.enable ? 1 : 0
  name                            = var.weka.name.resource
  resource_group_name             = azurerm_resource_group.weka[0].name
  location                        = azurerm_resource_group.weka[0].location
  sku                             = var.weka.machine.size
  instances                       = var.weka.machine.count
  source_image_id                 = var.weka.machine.image.id
  admin_username                  = local.weka.adminLogin.userName
  admin_password                  = local.weka.adminLogin.userPassword
  disable_password_authentication = var.weka.adminLogin.passwordAuth.disable
  proximity_placement_group_id    = azurerm_proximity_placement_group.weka[0].id
  single_placement_group          = false
  overprovision                   = false
  custom_data                     = base64encode(templatefile("terminate.sh", {
    wekaClusterName      = var.weka.name.resource
    wekaAdminPassword    = var.weka.adminLogin.userPassword
    dnsResourceGroupName = data.azurerm_private_dns_zone.network.resource_group_name
    dnsZoneName          = data.azurerm_private_dns_zone.network.name
    dnsRecordSetName     = var.weka.network.privateDnsZone.recordSetName
    binDirectory         = local.binDirectory
  }))
  network_interface {
    name    = "nic1"
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = local.storageSubnet.id
    }
    enable_accelerated_networking = var.weka.network.enableAcceleration
  }
  os_disk {
    storage_account_type = var.weka.osDisk.storageType
    caching              = var.weka.osDisk.cachingType
    disk_size_gb         = var.weka.osDisk.sizeGB
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
          wekaVersion               = "4.2.3"
          wekaApiToken              = var.weka.apiToken
          wekaClusterName           = var.weka.name.resource
          wekaDataDiskSize          = var.weka.dataDisk.sizeGB
          wekaMachineSpec           = local.wekaMachineSpec
          wekaCoreIdsScript         = local.wekaCoreIdsScript
          wekaDriveDisksScript      = local.wekaDriveDisksScript
          wekaFileSystemScript      = local.wekaFileSystemScript
          wekaFileSystemName        = var.weka.fileSystem.name
          wekaFileSystemAutoScale   = var.weka.fileSystem.autoScale
          wekaObjectTierPercent     = local.wekaObjectTier.percent
          wekaTerminateNotification = var.weka.terminateNotification
          wekaAdminPassword         = var.weka.adminLogin.userPassword
          wekaResourceGroupName     = azurerm_resource_group.weka[0].name
          dnsResourceGroupName      = data.azurerm_private_dns_zone.network.resource_group_name
          dnsZoneName               = data.azurerm_private_dns_zone.network.name
          dnsRecordSetName          = var.weka.network.privateDnsZone.recordSetName
          binDirectory              = local.binDirectory
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
    for_each = var.weka.machine.image.plan.enable ? [1] : []
    content {
      publisher = var.weka.machine.image.plan.publisher
      product   = var.weka.machine.image.plan.product
      name      = var.weka.machine.image.plan.name
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

resource "azurerm_private_dns_a_record" "content" {
  count               = var.weka.enable ? 1 : 0
  name                = var.weka.network.privateDnsZone.recordSetName
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  records             = [for vmInstance in data.azurerm_virtual_machine_scale_set.weka[0].instances : vmInstance.private_ip_address]
  ttl                 = var.weka.network.privateDnsZone.recordTtlSeconds
}

resource "terraform_data" "weka_cluster_create" {
  count = var.weka.enable ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "machineSpec='${local.wekaMachineSpec}'",
      "source ${local.wekaDriveDisksScript}",
      "weka cluster create ${join(" ", data.azurerm_virtual_machine_scale_set.weka[0].instances[*].private_ip_address)} --admin-password ${var.weka.adminLogin.userPassword} 2>&1 | tee weka-cluster-create.log",
      "weka user login admin ${var.weka.adminLogin.userPassword}",
      "for (( i=0; i<${var.weka.machine.count}; i++ )); do",
      "  hostName=${azurerm_linux_virtual_machine_scale_set.weka[0].name}$(printf %06X $i)",
      "  weka cluster drive add $i --HOST $hostName $nvmeDisks 2>&1 | tee --append weka-cluster-drive-add-$hostName.log",
      "done"
    ]
  }
}

resource "terraform_data" "weka_container_setup" {
  count = var.weka.enable ? var.weka.machine.count : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[count.index].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "failureDomain=$(hostname)",
      "machineSpec='${local.wekaMachineSpec}'",
      "source ${local.wekaCoreIdsScript}",
      "joinIps=${join(",", [for vmInstance in data.azurerm_virtual_machine_scale_set.weka[0].instances : vmInstance.private_ip_address])}",
      "sudo weka local setup container --name compute0 --base-port 15000 --failure-domain $failureDomain --join-ips $joinIps --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $computeMemory --no-frontends &> weka-container-setup-compute0.log",
      "sudo weka local setup container --name frontend0 --base-port 16000 --failure-domain $failureDomain --join-ips $joinIps --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate &> weka-container-setup-frontend0.log"
    ]
  }
  depends_on = [
    terraform_data.weka_cluster_create
  ]
}

resource "terraform_data" "weka_cluster_start" {
  count = var.weka.enable ? 1 : 0
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
      "  weka cluster license set ${var.weka.license.key} 2>&1 | tee weka-cluster-license.log",
      "elif [ \"${var.weka.license.payGo.planId}\" != \"\" ]; then",
      "  weka cluster license payg ${var.weka.license.payGo.planId} ${var.weka.license.payGo.secretKey} 2>&1 | tee weka-cluster-license.log",
      "fi",
      "weka cluster start-io"
    ]
  }
  depends_on = [
    terraform_data.weka_container_setup
  ]
}

resource "terraform_data" "weka_file_system" {
  count = var.weka.enable ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "ioStatus=$(weka status --json | jq -r .io_status)",
      "if [ $ioStatus == STARTED ]; then",
      "  source ${local.wekaFileSystemScript}",
      "  fileSystemGroupName=${var.weka.fileSystem.groupName}",
      "  fileSystemAuthRequired=${var.weka.fileSystem.authRequired ? "yes" : "no"}",
      "  fileSystemContainerName=${local.wekaObjectTier.storage.containerName}",
      "  if [ ${local.wekaObjectTier.enable} == true ]; then",
      "    weka fs tier s3 add $fileSystemContainerName --obs-type AZURE --hostname ${local.wekaObjectTier.storage.accountName}.blob.core.windows.net --secret-key ${nonsensitive(local.wekaObjectTier.storage.accountKey)} --access-key-id ${local.wekaObjectTier.storage.accountName} --bucket ${local.wekaObjectTier.storage.containerName} --protocol https --port 443",
      "  fi",
      "  weka fs group create $fileSystemGroupName",
      "  weka fs create $fileSystemName $fileSystemGroupName \"$fileSystemTotalBytes\"B --obs-name $fileSystemContainerName --ssd-capacity \"$fileSystemDriveBytes\"B --auth-required $fileSystemAuthRequired",
      "fi",
      "weka status"
    ]
  }
  depends_on = [
    azurerm_storage_container.core,
    terraform_data.weka_cluster_start
  ]
}

resource "terraform_data" "weka_load" {
  count = var.weka.enable && var.weka.fileSystem.loadFiles && var.fileLoadSource.accountName != "" ? 1 : 0
  connection {
    type     = "ssh"
    host     = data.azurerm_virtual_machine_scale_set.weka[0].instances[0].private_ip_address
    user     = var.weka.adminLogin.userName
    password = var.weka.adminLogin.userPassword
  }
  provisioner "remote-exec" {
    inline = [
      "sudo weka agent install-agent",
      "mountPath=/mnt/${var.fileLoadSource.containerName}",
      "sudo mkdir -p $mountPath",
      "sudo mount -t wekafs ${var.weka.fileSystem.name} $mountPath",
      "if [ \"${var.fileLoadSource.blobName}\" != \"\" ]; then",
      "  sudo az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --source-blob ${var.fileLoadSource.blobName} --recursive --destination /mnt/${var.fileLoadSource.containerName}",
      "else",
      "  sudo az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --recursive --destination /mnt",
      "fi"
    ]
  }
  depends_on = [
    terraform_data.weka_file_system
  ]
}

output "resourceGroupNameWeka" {
  value = var.weka.enable ? azurerm_resource_group.weka[0].name : ""
}
