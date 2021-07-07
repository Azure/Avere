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

  // vmss details
  vmss_resource_group_name = "vmss_rg"
  unique_name              = "vm"
  vm_count                 = 2
  vmss_size                = "Standard_D2s_v3"
  use_ephemeral_os_disk    = true

  // the below is the resource group and name of the previously created custom image
  image_resource_group = "image_resource_group"
  image_name           = "image_name"

  // network details
  virtual_network_resource_group = "network_resource_group"
  virtual_network_name           = "rendervnet"
  virtual_network_subnet_name    = "render_clients2"

  // update search domain with space separated list of search domains, leave blank to not set
  search_domain = ""

  // this value for OS Disk resize must be between 20GB and 1023GB,
  // after this you will need to repartition the disk
  os_disk_size_gb = 32

  script_file_b64 = base64gzip(replace(file("${path.module}/../installnfs.sh"), "\r", ""))
  cloud_init_file = templatefile("${path.module}/../cloud-init.tpl", { install_script = local.script_file_b64, search_domain = local.search_domain })
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subnet" "vnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resource_group
}

data "azurerm_image" "custom_image" {
  name                = local.image_name
  resource_group_name = local.image_resource_group
}

resource "azurerm_resource_group" "vmss" {
  name     = local.vmss_resource_group_name
  location = local.location
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

  custom_data     = base64encode(local.cloud_init_file)
  source_image_id = data.azurerm_image.custom_image.id

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

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = local.use_ephemeral_os_disk == true ? "ReadOnly" : "ReadWrite"
    disk_size_gb         = local.os_disk_size_gb

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
      subnet_id = data.azurerm_subnet.vnet.id
    }
  }
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
