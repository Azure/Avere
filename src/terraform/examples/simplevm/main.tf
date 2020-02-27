// customize the simple VM by adjusting the following local variables
locals {
    // network details
    network_resource_group_name = "network_resource_group"
    location = "eastus"
  
    // vm details
    vm_resource_group_name = "vm_resource_group"
    add_public_ip = true
    unique_name = "uniquename"
    vm_size = "Standard_D2s_v3"
    admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    admin_password = "PASSWORD"
    ssh_key_data = null //"ssh-rsa AAAAB3...."
}

module "network" {
    source = "../../modules/render_network"
    resource_group_name = local.network_resource_group_name
    location = local.location
}

provider "azurerm" {
    version = "~>2.0.0"
    features {}
}

data "azurerm_subnet" "vnet" {
    name                 = module.network.cloud_cache_subnet_name
    virtual_network_name = module.network.vnet_name
    resource_group_name  = local.network_resource_group_name
}

resource "azurerm_resource_group" "vm" {
    name     = local.vm_resource_group_name
    location = local.location
}

resource "azurerm_public_ip" "vm" {
    name                         = "${local.unique_name}-publicip"
    location                     = local.location
    resource_group_name          = azurerm_resource_group.vm.name
    allocation_method            = "Static"

    count = local.add_public_ip ? 1 : 0
}

resource "azurerm_network_interface" "vm" {
    name                = "${local.unique_name}-nic"
    location            = local.location
    resource_group_name = azurerm_resource_group.vm.name

    ip_configuration {
        name                          = "${local.unique_name}-ipconfig"
        subnet_id                     = data.azurerm_subnet.vnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = local.add_public_ip ? azurerm_public_ip.vm[0].id : ""
    }
}

resource "azurerm_linux_virtual_machine" "vm" {
    name = "${local.unique_name}-vm"
    location = local.location
    resource_group_name = azurerm_resource_group.vm.name
    network_interface_ids = [azurerm_network_interface.vm.id]
    computer_name = local.unique_name
    size = local.vm_size
    
    os_disk {
        name              = "${local.unique_name}-osdisk"
        caching           = "ReadWrite"
        storage_account_type  = "Standard_LRS"
    }

    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7-CI"
        version   = "latest"
    }

    admin_username = local.admin_username
    admin_password = (local.ssh_key_data == null || local.ssh_key_data == "") && local.admin_password != null && local.admin_password != "" ? local.admin_password : null
    disable_password_authentication = (local.ssh_key_data == null || local.ssh_key_data == "") && local.admin_password != null && local.admin_password != "" ? false : true
    dynamic "admin_ssh_key" {
        for_each = local.ssh_key_data == null || local.ssh_key_data == "" ? [] : [local.ssh_key_data]
        content {
            username   = local.admin_username
            public_key = admin_ssh_key.value
        }
    }
}

output "controller_username" {
  value = "${local.admin_username}"
}

output "controller_address" {
  value = "${local.add_public_ip ? azurerm_public_ip.vm[0].ip_address : azurerm_network_interface.vm.ip_configuration[0].private_ip_address}"
}


