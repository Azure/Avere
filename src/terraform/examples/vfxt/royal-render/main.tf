// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location                    = "westeurope"
  network_resource_group_name = "rr_network_rg"
  # storage_resource_group_name   = "rr_storage_rg"
  # vfxt_resource_group_name      = "rr_vfxt_rg"
  rr_server_resource_group_name = "rr_server_rg"
  vmss_resource_group_name      = "rr_vmss_rg"
  filer_resource_group_name     = "rr_nfs_filer_rg"

  // NFS Filer VM variables
  # nfs_vm_size = "Standard_L8s_v2"
  nfs_vm_size              = "Standard_D2s_v3"
  filer_private_ip_address = null

  // RR Server VM details
  rr_server_name    = "rrServer"
  rr_server_vm_size = "Standard_D2s_v3"
  vm_admin_password = "Password1234!"
  vm_admin_username = "azureuser"
  vm_ssh_key_data   = null
  ssh_port          = 22

  // storage details
  # storage_account_name = "rrtest1234"
  # avere_storage_container_name = "rr"
  # nfs_export_path = "/rr-demo"

  // vfxt details
  // if you are running a locked down network, set controller_add_public_ip to false
  # controller_add_public_ip = true
  # vfxt_cluster_name = "vfxt"
  # vfxt_cluster_password = "VFXT_PASSWORD"
  # vfxt_ssh_key_data = local.vm_ssh_key_data

  // vmss details
  vmss_name       = "vmss"
  vmss_priority   = "Low"
  vmss_count      = 2
  vmss_size       = "Standard_D2s_v3"
  rr_mount_target = "/nfs/rr"
  mount_target    = "/nfs"

  alternative_resource_groups = []
  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [local.ssh_port, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
}

terraform {
  required_version = ">= 0.14.0,< 0.16.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources
}

# resource "azurerm_resource_group" "storage" {
#   name     = local.storage_resource_group_name
#   location = local.location
# }

# resource "azurerm_storage_account" "storage" {
#   name                     = local.storage_account_name
#   resource_group_name      = azurerm_resource_group.storage.name
#   location                 = azurerm_resource_group.storage.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   network_rules {
#       virtual_network_subnet_ids = [
#           module.network.cloud_cache_subnet_id,
#           // need for the controller to create the container
#           module.network.jumpbox_subnet_id,
#       ]
#       default_action = "Deny"
#   }
#   // if the nsg associations do not complete before the storage account
#   // create is started, it will fail with "subnet updating"
#   depends_on = [module.network]
# }

# // the vfxt controller
# module "vfxtcontroller" {
#     source = "github.com/Azure/Avere/src/terraform/modules/controller3"
#     resource_group_name = local.vfxt_resource_group_name
#     location = local.location
#     admin_username = local.vm_admin_username
#     ssh_key_data = local.vm_ssh_key_data
#     add_public_ip = local.controller_add_public_ip
#     alternative_resource_groups = local.alternative_resource_groups
#     ssh_port = local.ssh_port

#     // network details
#     virtual_network_resource_group = module.network.vnet_resource_group
#     virtual_network_name = module.network.vnet_name
#     virtual_network_subnet_name = module.network.jumpbox_subnet_name

#     module_depends_on = [module.network.vnet_id]
# }

# # // the vfxt
# resource "avere_vfxt" "vfxt" {
#     controller_address = module.vfxtcontroller.controller_address
#     controller_admin_username = module.vfxtcontroller.controller_username
#     controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
#     controller_ssh_port = local.ssh_port
#     // terraform is not creating the implicit dependency on the controller module
#     // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
#     // to work around, add the explicit dependency
#     depends_on = [module.vfxtcontroller]

#     location = local.location
#     azure_resource_group = local.vfxt_resource_group_name
#     azure_network_resource_group = module.network.vnet_resource_group
#     azure_network_name = module.network.vnet_name
#     azure_subnet_name = module.network.cloud_cache_subnet_name
#     vfxt_cluster_name = local.vfxt_cluster_name
#     vfxt_admin_password = local.vfxt_cluster_password
#     vfxt_ssh_key_data = local.vfxt_ssh_key_data
#     vfxt_node_count = 3

#     # node_size = "unsupported_test_SKU"
#     # node_cache_size = 1024

#     azure_storage_filer {
#         account_name = local.storage_account_name
#         container_name = local.avere_storage_container_name
#         custom_settings = []
#         junction_namespace_path = local.nfs_export_path
#     }
# } 

resource "azurerm_resource_group" "nfsfiler_rg" {
  name     = local.filer_resource_group_name
  location = local.location
}

// the ephemeral filer
module "nfsfiler" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.nfsfiler_rg.name
  location            = azurerm_resource_group.nfsfiler_rg.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = local.nfs_vm_size
  unique_name         = "nfsfiler"

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.cloud_filers_subnet_name
  private_ip_address             = local.filer_private_ip_address

  module_depends_on = [azurerm_resource_group.nfsfiler_rg, module.network.vnet_id]
}

resource "azurerm_resource_group" "rr_server_rg" {
  name     = local.rr_server_resource_group_name
  location = local.location
}

resource "azurerm_public_ip" "rr_server_public_ip" {
  name                = "${local.rr_server_name}-public-ip"
  resource_group_name = local.rr_server_resource_group_name
  location            = local.location
  allocation_method   = "Static"

  depends_on = [azurerm_resource_group.rr_server_rg]
}

resource "azurerm_network_interface" "rr_server_nic" {
  name                = "${local.rr_server_name}-nic"
  location            = local.location
  resource_group_name = local.rr_server_resource_group_name

  ip_configuration {
    name                          = "rrserverconfiguration"
    subnet_id                     = module.network.jumpbox_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rr_server_public_ip.id
  }

  depends_on = [module.network, azurerm_public_ip.rr_server_public_ip]
}

resource "azurerm_virtual_machine" "rr_server" {
  name                  = local.rr_server_name
  location              = local.location
  resource_group_name   = local.rr_server_resource_group_name
  vm_size               = local.rr_server_vm_size
  network_interface_ids = [azurerm_network_interface.rr_server_nic.id]


  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${local.rr_server_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  dynamic "os_profile" {
    for_each = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? [local.vm_admin_password] : [null]
    content {
      computer_name  = local.rr_server_name
      admin_username = local.vm_admin_username
      admin_password = os_profile.value
      custom_data    = templatefile("${path.module}/cloud-init.yml", { nfsfiler = module.nfsfiler.nfs_mount, ssh_port = local.ssh_port })
    }
  }
  // dynamic block when password is specified
  dynamic "os_profile_linux_config" {
    for_each = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? [local.vm_admin_password] : []
    content {
      disable_password_authentication = false
    }
  }
  // dynamic block when SSH key is specified
  dynamic "os_profile_linux_config" {
    for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
    content {
      disable_password_authentication = true
      ssh_keys {
        key_data = local.vm_ssh_key_data
        path     = "/home/${local.vm_admin_username}/.ssh/authorized_keys"
      }
    }
  }

  # depends_on = [avere_vfxt.vfxt]
  depends_on = [module.nfsfiler]
}

resource "azurerm_resource_group" "vmss" {
  name     = local.vmss_resource_group_name
  location = local.location
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = local.vmss_name
  resource_group_name = azurerm_resource_group.vmss.name
  location            = azurerm_resource_group.vmss.location
  upgrade_policy_mode = "Manual"
  priority            = local.vmss_priority
  eviction_policy     = local.vmss_priority == "Spot" ? "Delete" : null
  overprovision       = false

  dynamic "os_profile" {
    for_each = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? [local.vm_admin_password] : [null]
    content {
      computer_name_prefix = local.vmss_name
      admin_username       = local.vm_admin_username
      admin_password       = local.vm_admin_password
      custom_data          = templatefile("${path.module}/cloud-init-vmss.yml", { nfsfiler = module.nfsfiler.nfs_mount, ssh_port = local.ssh_port })
    }
  }

  // dynamic block when password is specified
  dynamic "os_profile_linux_config" {
    for_each = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? [local.vm_admin_password] : []
    content {
      disable_password_authentication = false
    }
  }

  // dynamic block when SSH key is specified
  dynamic "os_profile_linux_config" {
    for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
    content {
      disable_password_authentication = true
      ssh_keys {
        path     = "/home/${local.vm_admin_username}/.ssh/authorized_keys"
        key_data = local.vm_ssh_key_data
      }
    }
  }

  sku {
    name     = local.vmss_size
    tier     = "Standard"
    capacity = local.vmss_count
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
  }

  network_profile {
    name    = "vminic-${local.vmss_name}"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = module.network.render_clients1_subnet_id
    }
  }
  depends_on = [module.nfsfiler]
}

output "rr_server_vm_ssh" {
  value = "ssh ${local.vm_admin_username}@${azurerm_public_ip.rr_server_public_ip.ip_address}"
}

output "nfsfiler_username" {
  value = module.nfsfiler.admin_username
}

output "nfsfiler_address" {
  value = module.nfsfiler.primary_ip
}

output "nfsfiler_ssh_string" {
  value = module.nfsfiler.ssh_string
}

output "list_disks_az_cli" {
  value = "az disk list --query \"[?resourceGroup=='${upper(azurerm_resource_group.nfsfiler_rg.name)}'].id\""
}

# output "controller_username" {
#   value = module.vfxtcontroller.controller_username
# }

# output "controller_address" {
#   value = module.vfxtcontroller.controller_address
# }

# output "controller_ssh_port" {
#   value = local.ssh_port
# }

# output "ssh_command_with_avere_tunnel" {
#     value = "ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
# }

# output "management_ip" {
#     value = avere_vfxt.vfxt.vfxt_management_ip
# }

# output "mount_addresses" {
#     value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
# }
