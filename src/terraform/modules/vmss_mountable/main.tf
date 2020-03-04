// customize the simple VM by editing the following local variables
locals {
    vm_name = "vm-${unique_name}"
}

data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

resource "azurerm_resource_group" "vmss" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = local.vm_name
  resource_group_name = azurerm_resource_group.vmss.name
  location            = azurerm_resource_group.vmss.location
  sku                 = var.vm_size
  instances           = var.vm_count
  admin_username      = var.admin_username

  dynamic "admin_ssh_key" {
      for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
      content {
          username   = var.admin_username
          public_key = var.ssh_key_data
      }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vminic-${var.unique}"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = data.azurerm_subnet.vnet.id
    }
  }
}

locals {
    env_vars = " LINUX_USER=${var.admin_username} NODE_PREFIX=${local.vm_name} NODE_COUNT=${var.vm_count} BASE_DIR=${var.mount_target} BOOTSTRAP_SCRIPT_PATH=${var.bootstrap_script_path} NFS_IP_CSV=\"${join(var.mount_addresses)}\" NFS_PATH=${var.nfs_export_path}"

    bootstrap_path = "/b"
}

resource "azurerm_virtual_machine_scale_set_extension" "vmss" {
  name                         = "${var.unique_name}-cse"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vmss.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  # steps of the installer
  # 1. install nfs-common
  # 2. create the bootstrap directory and mount the nfs server
  # 3. run the bootstrap script
  # 4. unmount the nfs server the bootstrap directory 
  settings = <<SETTINGS
    {
        "commandToExecute": "apt-get update && apt-get install -y nfs-common && mkdir -p ${local.bootstrap_path} && r=5 && for i in $(seq 1 $r); do mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.mount_addresses[0]}:${var.nfs_export_path} ${local.bootstrap_path} && break || [ $i == $r ] && break 0 || sleep 1; done && ${local.env_vars} /bin/bash ${local.bootstrap_path}${var.bootstrap_script_path} 2>&1 | tee -a /var/log/bootstrap.log && umount ${local.bootstrap_path} && rmdir ${local.bootstrap_path}"
    }
SETTINGS
}