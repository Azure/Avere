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
    name                         = "public_ip"
    location                     = local.location
    resource_group_name          = azurerm_resource_group.vm.name
    allocation_method            = "Static"

    count = local.add_public_ip ? 1 : 0
}

resource "azurerm_network_interface" "vm" {
    name                = "${local.unique_name}-nic"
    resource_group_name = azurerm_resource_group.vm.name
    location            = local.location

    ip_configuration {
        name                          = "ipconfig"
        subnet_id                     = data.azurerm_subnet.vnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = local.add_public_ip ? azurerm_public_ip.vm[0].id : ""
    }
}

resource "azurerm_virtual_machine" "vm" {
    name = "${local.unique_name}-vm"
    location = local.location
    resource_group_name = azurerm_resource_group.vm.name
    network_interface_ids = [azurerm_network_interface.vm.id]
    vm_size = local.vm_size
    delete_os_disk_on_termination = true

    storage_os_disk {
        name              = "os_disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7-CI"
        version   = "latest"
    }

    dynamic "os_profile" {
        for_each = (local.ssh_key_data == null || local.ssh_key_data == "") && local.admin_password != null && local.admin_password != "" ? [local.admin_password] : [null] 
        content {
            computer_name  = local.unique_name
            admin_username = local.admin_username
            admin_password = os_profile.value
        }
    }

    // dynamic block when password is specified
    dynamic "os_profile_linux_config" {
        for_each = (local.ssh_key_data == null || local.ssh_key_data == "") && local.admin_password != null && local.admin_password != "" ? [local.admin_password] : [null] 
        content {
            disable_password_authentication = false
        }
    }

    // dynamic block when SSH key is specified
    dynamic "os_profile_linux_config" {
        for_each = local.ssh_key_data == null || local.ssh_key_data == "" ? [] : [local.ssh_key_data]
        content {
            disable_password_authentication = true
            ssh_keys {
                path     = "/home/${local.admin_username}/.ssh/authorized_keys"
                key_data = os_profile_linux_config.value
            }
        }
    }
}