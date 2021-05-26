// anvil can be standard or ha
// ha will install
//   1. load balancer
//   2. ip address
//   3. balance across an HA network
//

locals {
  // best practice is to ensure the ha_subnet needs to be isolated
  anvil_dynamic_cluster_ip = var.anvil_data_cluster_ip == ""
  load_balancer_fe_name    = "${var.unique_name}LoadBalancerFrontEnd"

  // advanced
  domain               = "${var.unique_name}.azure"
  is_high_availability = var.anvil_configuration == "High Availability"
}

data "azurerm_subnet" "data_subnet" {
  name                 = var.virtual_network_data_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_subnet" "ha_subnet" {
  name                 = var.virtual_network_ha_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

resource "azurerm_lb" "anvilloadbalancer" {
  count               = local.is_high_availability ? 1 : 0
  name                = "${var.unique_name}LoadBalancer"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = local.load_balancer_fe_name
    private_ip_address_version    = "IPv4"
    private_ip_address_allocation = local.anvil_dynamic_cluster_ip ? "Dynamic" : "Static"
    private_ip_address            = local.anvil_dynamic_cluster_ip ? null : var.anvil_data_cluster_ip
    subnet_id                     = data.azurerm_subnet.data_subnet.id
  }
}

resource "azurerm_lb_backend_address_pool" "anvilloadbalancerbepool" {
  count           = local.is_high_availability ? 1 : 0
  loadbalancer_id = azurerm_lb.anvilloadbalancer[0].id
  name            = "${var.unique_name}LoadBalancerBEPool"
}

resource "azurerm_lb_probe" "anvilloadbalancerprobe" {
  count               = local.is_high_availability ? 1 : 0
  resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.anvilloadbalancer[0].id
  name                = "${var.unique_name}LoadBalancerProbe"
  port                = 4505
  protocol            = "Tcp"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "anvilloadbalancerlbrule" {
  count                          = local.is_high_availability ? 1 : 0
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.anvilloadbalancer[0].id
  name                           = "${var.unique_name}LoadBalancerRule"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = local.load_balancer_fe_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.anvilloadbalancerbepool[0].id
  probe_id                       = azurerm_lb_probe.anvilloadbalancerprobe[0].id
  enable_floating_ip             = true
}

locals {
  anvil_node_count = local.is_high_availability ? 2 : 1

  anvil_host_names = [for i in range(local.anvil_node_count) :
    "${var.unique_name}anvil${i}"
  ]

  //data_mask_bits = reverse(split("/", data.azurerm_subnet.data_subnet.address_prefixes[0]))[0]
  // must use a hardcoded number so it doesn't recreate the vms, otherwise 
  // the functions above force custom_data to be unknown, causing re-creation
  data_mask_bits = var.virtual_network_data_subnet_mask_bits

  anvil_lb_ip = local.is_high_availability ? azurerm_lb.anvilloadbalancer[0].frontend_ip_configuration[0].private_ip_address : ""

  // configure the custom data
  standalone_custom_data = [
    <<EOT
{
    "cluster": {
        "domainname": "${local.domain}",
        "ntp_servers": [
            "${var.ntp_server}"
        ]
    },
    "node": {
        "hostname": "${local.anvil_host_names[0]}"
    }
}
EOT
  ]
  // ha_custom_data
  ha_custom_data = local.is_high_availability == false ? [] : [
    <<EOT
{
    "cluster": {
        "domainname": "${local.domain}",
        "ntp_servers": [
            "${var.ntp_server}"
        ]
    },
    "node": {
        "hostname": "${local.anvil_host_names[0]}",
        "ha_mode": "Secondary",
        "networks": {
            "eth0": {
                "cluster_ips": [
                    "${local.anvil_lb_ip}/${local.data_mask_bits}"
                ]
            }
        }
    }
}
EOT
    , <<EOT
{
    "cluster": {
        "domainname": "${local.domain}",
        "ntp_servers": [
            "${var.ntp_server}"
        ]
    },
    "node": {
        "hostname": "${local.anvil_host_names[1]}",
        "ha_mode": "Primary",
        "networks": {
            "eth0": {
                "cluster_ips": [
                    "${local.anvil_lb_ip}/${local.data_mask_bits}"
                ]
            }
        }
    }
}
EOT
  ]
}

resource "azurerm_network_interface" "anvildata" {
  count               = local.anvil_node_count
  name                = "${local.anvil_host_names[count.index]}-datanic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    primary                       = true
    private_ip_address_allocation = local.is_high_availability || local.anvil_dynamic_cluster_ip ? "Dynamic" : "Static"
    private_ip_address            = local.is_high_availability || local.anvil_dynamic_cluster_ip ? null : var.anvil_data_cluster_ip
    subnet_id                     = data.azurerm_subnet.data_subnet.id
  }
}

resource "azurerm_network_interface" "anvilha" {
  count               = local.is_high_availability ? 2 : 0
  name                = "${local.anvil_host_names[count.index]}-hanic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    primary                       = false
    private_ip_address_allocation = local.is_high_availability || local.anvil_dynamic_cluster_ip ? "Dynamic" : "Static"
    private_ip_address            = local.is_high_availability || local.anvil_dynamic_cluster_ip ? null : var.anvil_data_cluster_ip
    subnet_id                     = data.azurerm_subnet.ha_subnet.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "anvilha" {
  count                   = local.is_high_availability ? 2 : 0
  network_interface_id    = azurerm_network_interface.anvildata[count.index].id
  ip_configuration_name   = "${var.unique_name}-ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.anvilloadbalancerbepool[0].id
}

resource "azurerm_availability_set" "anvilas" {
  count               = local.is_high_availability ? 1 : 0
  name                = "${var.unique_name}AvailSet"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_linux_virtual_machine" "anvilvm" {
  count                 = local.is_high_availability ? 2 : 1
  name                  = local.anvil_host_names[count.index]
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = local.is_high_availability ? [azurerm_network_interface.anvildata[count.index].id, azurerm_network_interface.anvilha[count.index].id] : [azurerm_network_interface.anvildata[count.index].id]
  computer_name         = local.anvil_host_names[count.index]
  custom_data           = base64encode(local.is_high_availability ? local.ha_custom_data[count.index] : local.standalone_custom_data[count.index])
  size                  = var.anvil_instance_type
  source_image_id       = var.hammerspace_image_id
  availability_set_id   = local.is_high_availability ? azurerm_availability_set.anvilas[0].id : null

  os_disk {
    name                 = "${local.anvil_host_names[count.index]}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.anvil_boot_disk_storage_type
    disk_size_gb         = var.anvil_boot_disk_size
  }

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  // add depends_on so deletion happens successfully
  depends_on = [
    azurerm_availability_set.anvilas,
  ]
}

resource "azurerm_managed_disk" "anvilvm" {
  count                = var.anvil_metadata_disk_size == 0 ? 0 : local.is_high_availability ? 2 : 1
  name                 = "${local.anvil_host_names[count.index]}-disk1"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.anvil_metadata_disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = var.anvil_metadata_disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "anvilvm" {
  count              = var.anvil_metadata_disk_size == 0 ? 0 : local.is_high_availability ? 2 : 1
  managed_disk_id    = azurerm_managed_disk.anvilvm[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.anvilvm[count.index].id
  lun                = "1"
  caching            = azurerm_managed_disk.anvilvm[count.index].disk_size_gb > 4095 ? "None" : "ReadWrite"
}
