data "azurerm_subnet" "data_subnet" {
  name                 = var.virtual_network_data_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

locals {
  dsx_host_names = [for i in range(var.dsx_instance_count): 
    "${var.unique_name}dsx${i}"
  ]

  dsx_custom_data = [for i in range(var.dsx_instance_count): 
    <<EOT
{
    "cluster": {
        "domainname": "${var.anvil_domain}",
        "metadata": {
            "ips": [
                "${var.anvil_data_cluster_ip}/${var.anvil_data_cluster_ip_mask_bits}"
            ]
        }
    },
    "node": {
        "features": [
            "portal",
            "storage"
        ],
        "hostname": "${local.dsx_host_names[i]}"
    }
}
EOT
  ]
}

resource "azurerm_network_interface" "dsxdata" {
  count               = var.dsx_instance_count
  name                = "${local.dsx_host_names[count.index]}-datanic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    primary                       = true
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = data.azurerm_subnet.data_subnet.id
  }
}

resource "azurerm_linux_virtual_machine" "dsxvm" {
  count                 = var.dsx_instance_count
  name                  = local.dsx_host_names[count.index]
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [ azurerm_network_interface.dsxdata[count.index].id ]
  computer_name         = local.dsx_host_names[count.index]
  custom_data           = base64encode(local.dsx_custom_data[count.index])
  size                  = var.dsx_instance_type
  source_image_id       = var.hammerspace_image_id
  
  os_disk {
    name                 = "${local.dsx_host_names[count.index]}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.dsx_boot_disk_storage_type
    disk_size_gb         = var.dsx_boot_disk_size
  }

  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = false
}

resource "azurerm_managed_disk" "dsxvm" {
  count                = var.dsx_instance_count
  name                 = "${local.dsx_host_names[count.index]}-datadisk"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.dsx_data_disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = var.dsx_data_disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "dsxvm" {
  count              = var.dsx_instance_count
  managed_disk_id    = azurerm_managed_disk.dsxvm[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.dsxvm[count.index].id
  lun                = "1"
  caching            = azurerm_managed_disk.dsxvm[count.index].disk_size_gb > 4095 ? "None" : "ReadWrite"
}