data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_resource_group" "cyclecloud" {
  name     = var.resource_group_name
}

data "azurerm_subscription" "primary" {}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/installnfs.sh"),"\r",""))
  proxy_env = (var.proxy == null || var.proxy == "") ? "" : "http_proxy=${var.proxy} https_proxy=${var.proxy} no_proxy=169.254.169.254"
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { install_script = local.script_file_b64})

  centos_source_image = {
    publisher = "OpenLogic"
    offer     = "CentOS-CI"
    # only 7-CI supports cloud-init https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init
    sku       = "7-CI"
    version   = "latest"
  }

  cycle_cloud_image = {
    "publisher": "azurecyclecloud",
    "offer": "azure-cyclecloud",
    "sku": "cyclecloud-81",
    "version": "latest"
  }

  target_image = var.use_marketplace ? local.cycle_cloud_image : local.centos_source_image
}

resource "azurerm_network_interface" "cyclecloud" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.cyclecloud.name
  location            = data.azurerm_resource_group.cyclecloud.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "cyclecloud" {
  name = "${var.unique_name}-vm"
  resource_group_name = data.azurerm_resource_group.cyclecloud.name
  location = data.azurerm_resource_group.cyclecloud.location
  network_interface_ids = [azurerm_network_interface.cyclecloud.id]
  vm_size = var.vm_size

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = local.target_image.publisher
    offer     = local.target_image.offer
    sku       = local.target_image.sku
    version   = local.target_image.version
  }

  dynamic "plan" {
    for_each = var.use_marketplace ? [var.use_marketplace] : []
    content {
      name = "cyclecloud-81"
      publisher = "azurecyclecloud"
      product = "azure-cyclecloud"
    }
  }

  storage_os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  dynamic "storage_data_disk" {
    for_each = var.use_marketplace ? [var.use_marketplace] : []
    content {
      lun               = 0
      name              = "${var.unique_name}-datadisk"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Premium_LRS"
      disk_size_gb      = 128
    }
  }

  os_profile {
    computer_name  = var.unique_name
    admin_username = var.admin_username
    admin_password = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? var.admin_password : null
    custom_data = base64encode(local.cloud_init_file)
  }

  os_profile_linux_config {
    disable_password_authentication = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? false : true
    dynamic "ssh_keys" {
      for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
      content {
          path     = "/home/${var.admin_username}/.ssh/authorized_keys"
          key_data = var.ssh_key_data
      }
    }
  }
}

resource "azurerm_virtual_machine_extension" "cse" {
  name = "${var.unique_name}-cse"
  virtual_machine_id   = azurerm_virtual_machine.cyclecloud.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " ${local.proxy_env} USE_MARKETPLACE=${var.use_marketplace} /bin/bash /opt/installcycle.sh 2>&1 | tee -a /var/log/installcycle.log"
    }
SETTINGS
}

resource "azurerm_role_assignment" "create_cluster_role" {
  scope                            = data.azurerm_subscription.primary.id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_virtual_machine.cyclecloud.identity[0].principal_id
  skip_service_principal_aad_check = true
}
