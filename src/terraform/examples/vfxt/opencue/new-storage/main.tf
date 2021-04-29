////////////////////////////////////////////////////////////////////////////////////////
// WARNING: if you get an error deploying, please review https://aka.ms/avere-tf-prereqs
////////////////////////////////////////////////////////////////////////////////////////
locals {
  // the region of the deployment
  location                    = "eastus"
  network_resource_group_name = "opencue_network_rg"
  storage_resource_group_name = "opencue_storage_rg"
  vfxt_resource_group_name    = "opencue_vfxt_rg"
  cuebot_resource_group_name  = "opencue_cuebot_rg"
  vmss_resource_group_name    = "opencue_vmss_rg"

  // CueBot VM details
  cuebot_name       = "cuebot"
  cuebot_vm_size    = "Standard_D2s_v3" // Min 6GB RAM required by cuebot
  vm_admin_password = "Password1234!"
  vm_admin_username = "azureuser"
  vm_ssh_key_data   = "ssh-rsa AAAAB3...."
  ssh_port          = 22

  // storage details
  storage_account_name         = "opencuetest1234"
  avere_storage_container_name = "opencue"
  nfs_export_path              = "/opencue-demo"

  // vfxt details
  // if you are running a locked down network, set controller_add_public_ip to false
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  vfxt_ssh_key_data        = local.vm_ssh_key_data

  # download the latest moana island scene from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
  # and upload to an azure storage blob and put the URL below

  // vmss details
  unique_name      = "vmss"
  vmss_priority    = "Low"
  vm_count         = 2
  vmss_size        = "Standard_D2s_v3"
  mount_target     = "/nfs"
  opencue_env_vars = "CUE_FS_ROOT=${local.mount_target}/opencue-demo"

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

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    virtual_network_subnet_ids = [
      module.network.cloud_cache_subnet_id,
      // need for the controller to create the container
      module.network.jumpbox_subnet_id,
    ]
    default_action = "Deny"
  }
  // if the nsg associations do not complete before the storage account
  // create is started, it will fail with "subnet updating"
  depends_on = [
    module.network,
  ]
}

// the vfxt controller
module "vfxtcontroller" {
  source                      = "github.com/Azure/Avere/src/terraform/modules/controller3"
  resource_group_name         = local.vfxt_resource_group_name
  location                    = local.location
  admin_username              = local.vm_admin_username
  ssh_key_data                = local.vm_ssh_key_data
  add_public_ip               = local.controller_add_public_ip
  alternative_resource_groups = local.alternative_resource_groups
  ssh_port                    = local.ssh_port

  // network details
  virtual_network_resource_group = module.network.vnet_resource_group
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    module.network,
  ]
}

# // the vfxt
resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = module.vfxtcontroller.controller_username
  controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
  controller_ssh_port       = local.ssh_port

  location                     = local.location
  azure_resource_group         = local.vfxt_resource_group_name
  azure_network_resource_group = module.network.vnet_resource_group
  azure_network_name           = module.network.vnet_name
  azure_subnet_name            = module.network.cloud_cache_subnet_name
  vfxt_cluster_name            = local.vfxt_cluster_name
  vfxt_admin_password          = local.vfxt_cluster_password
  vfxt_ssh_key_data            = local.vfxt_ssh_key_data
  vfxt_node_count              = 3

  # node_size = "unsupported_test_SKU"
  # node_cache_size = 1024

  azure_storage_filer {
    account_name            = local.storage_account_name
    container_name          = local.avere_storage_container_name
    custom_settings         = []
    junction_namespace_path = local.nfs_export_path
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller,
  ]
}

resource "azurerm_resource_group" "cuebot_rg" {
  name     = local.cuebot_resource_group_name
  location = local.location
}

resource "azurerm_public_ip" "cuebot_public_ip" {
  name                = "${local.cuebot_name}-public-ip"
  resource_group_name = local.cuebot_resource_group_name
  location            = local.location
  allocation_method   = "Static"

  depends_on = [
    azurerm_resource_group.cuebot_rg,
  ]
}

resource "azurerm_network_interface" "cuebot_nic" {
  name                = "${local.cuebot_name}-nic"
  location            = local.location
  resource_group_name = local.cuebot_resource_group_name

  ip_configuration {
    name                          = "cuebotconfiguration"
    subnet_id                     = module.network.jumpbox_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cuebot_public_ip.id
  }

  depends_on = [
    module.network,
    azurerm_public_ip.cuebot_public_ip,
  ]
}

resource "azurerm_virtual_machine" "cuebot" {
  name                  = local.cuebot_name
  location              = local.location
  resource_group_name   = local.cuebot_resource_group_name
  vm_size               = local.cuebot_vm_size
  network_interface_ids = [azurerm_network_interface.cuebot_nic.id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${local.cuebot_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  dynamic "os_profile" {
    for_each = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? [local.vm_admin_password] : [null]
    content {
      computer_name  = local.cuebot_name
      admin_username = local.vm_admin_username
      admin_password = os_profile.value
      custom_data    = templatefile("${path.module}/cloud-init.yml", { namespace_path = local.nfs_export_path, ssh_port = local.ssh_port, cache_ip = tolist(avere_vfxt.vfxt.vserver_ip_addresses)[0] }) //local.cuebot_vm_cloud_init
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

  depends_on = [
    avere_vfxt.vfxt,
  ]
}

// the opencue module
module "opencue_configure" {
  source = "github.com/Azure/Avere/src/terraform/modules/opencue_config"

  node_address    = module.vfxtcontroller.controller_address
  admin_username  = module.vfxtcontroller.controller_username
  ssh_key_data    = local.vm_ssh_key_data
  nfs_address     = tolist(avere_vfxt.vfxt.vserver_ip_addresses)[0]
  nfs_export_path = local.nfs_export_path
  ssh_port        = local.ssh_port

  depends_on = [
    module.vfxtcontroller,
    avere_vfxt.vfxt,
  ]
}

// the VMSS module
module "vmss" {
  source = "github.com/Azure/Avere/src/terraform/modules/vmss_mountable"

  resource_group_name            = local.vmss_resource_group_name
  location                       = local.location
  vmss_priority                  = local.vmss_priority
  admin_username                 = module.vfxtcontroller.controller_username
  ssh_key_data                   = local.vm_ssh_key_data
  unique_name                    = local.unique_name
  vm_count                       = local.vm_count
  vm_size                        = local.vmss_size
  virtual_network_resource_group = module.network.vnet_resource_group
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.render_clients1_subnet_name
  mount_target                   = local.mount_target
  nfs_export_addresses           = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
  nfs_export_path                = local.nfs_export_path
  additional_env_vars            = "${local.opencue_env_vars} CUEBOT_HOSTNAME=${azurerm_network_interface.cuebot_nic.private_ip_address}"
  bootstrap_script_path          = module.opencue_configure.bootstrap_script_path
  depends_on = [
    module.opencue_configure,
    azurerm_virtual_machine.cuebot,
    module.vfxtcontroller,
    module.network,
    azurerm_network_interface.cuebot_nic,
  ]
}

output "cuebot_vm_ssh" {
  value = "ssh ${local.vm_admin_username}@${azurerm_public_ip.cuebot_public_ip.ip_address}"
}

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "controller_ssh_port" {
  value = local.ssh_port
}

output "ssh_command_with_avere_tunnel" {
  value = "ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
  value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
  value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "vmss_id" {
  value = module.vmss.vmss_id
}

output "vmss_resource_group" {
  value = module.vmss.vmss_resource_group
}

output "vmss_name" {
  value = module.vmss.vmss_name
}

output "vmss_addresses_command" {
  // local-exec doesn't return output, and the only way to 
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${local.vmss_resource_group_name} --vmss-name ${module.vmss.vmss_name} --query \"[].ipConfigurations[].privateIpAddress\""
}
