// customize the VMSS by editing the following local variables
locals {
  // the region of the deployment
  location          = "eastus"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // network details
  virtual_network_resource_group = "network_resource_group"

  // vmss details
  vmss_resource_group_name = "vmss_rg"
  unique_name              = "unique"
  vm_count                 = 3
  vmss_size                = "Standard_D2s_v3"
  use_ephemeral_os_disk    = true
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

resource "azurerm_resource_group" "vmss" {
  name     = local.vmss_resource_group_name
  location = local.location
}

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.virtual_network_resource_group
  location            = local.location
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                            = local.unique_name
  resource_group_name             = azurerm_resource_group.vmss.name
  location                        = azurerm_resource_group.vmss.location
  sku                             = local.vmss_size
  instances                       = local.vm_count
  admin_username                  = local.vm_admin_username
  admin_password                  = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? local.vm_admin_password : null
  disable_password_authentication = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? false : true

  # use low-priority with Delete.  Stop Deallocate will be incompatible with OS Ephemeral disks
  priority        = "Spot"
  eviction_policy = "Delete"
  // avoid overprovision as it can create race conditions with render managers
  overprovision = false
  // avoid use of zones so you get maximum spread of machines, and have > 100 nodes
  single_placement_group = false
  // avoid use of zones so you get maximum spread of machines
  zone_balance = false
  zones        = []
  // avoid use proximity groups so you get maximum spread of machines
  // proximity_placement_group_id

  dynamic "admin_ssh_key" {
    for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
    content {
      username   = local.vm_admin_username
      public_key = local.vm_ssh_key_data
    }
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = local.use_ephemeral_os_disk == true ? "ReadOnly" : "ReadWrite"

    dynamic "diff_disk_settings" {
      for_each = local.use_ephemeral_os_disk == true ? [local.use_ephemeral_os_disk] : []
      content {
        option = "Local"
      }
    }
  }

  network_interface {
    name                          = "vminic-${local.unique_name}"
    primary                       = true
    enable_accelerated_networking = false

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = module.network.render_clients1_subnet_id
    }
  }

  depends_on = [
    module.network,
  ]
}

output "vmss_id" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.id
}

output "vmss_resource_group" {
  value = azurerm_resource_group.vmss.name
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.name
}

output "vmss_addresses_command" {
  // local-exec doesn't return output, and the only way to 
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${azurerm_resource_group.vmss.name} --vmss-name ${azurerm_linux_virtual_machine_scale_set.vmss.name} --query \"[].ipConfigurations[].privateIpAddress\""
}
