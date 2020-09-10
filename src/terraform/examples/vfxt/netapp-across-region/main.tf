// customize the simple VM by editing the following local variables
locals {
    // the region of the main deployment
    location = "eastus"
    network_resource_group_name = "network_resource_group"
    
    // netapp filer details
    filer_location = "westus2"
    filer_resource_group_name = "filer_resource_group"
    netapp_account_name = "netappaccount"
    export_path = "data"
    // possible values are Standard, Premium, Ultra
    service_level = "Premium"
    pool_size_in_tb = 4
    volume_storage_quota_in_gb = 100

    // vnet to vnet settings
    vpngw_generation = "Generation1" // generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
    vpngw_sku = "VpnGw2"
    shared_key = "5v2ty45bt171p53c5h4r3dk4y"

    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "VFXT_PASSWORD"
    vfxt_ssh_key_data = local.vm_ssh_key_data
    // vfxt cache polies
    //  "Clients Bypassing the Cluster"
    //  "Read Caching"
    //  "Read and Write Caching"
    //  "Full Caching"
    //  "Transitioning Clients Before or After a Migration"
    cache_policy = "Clients Bypassing the Cluster"
    
    // controller details
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
    ssh_port = 22

    // controller details
    controller_add_public_ip = true

    // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
    open_external_ports = [local.ssh_port,3389]
    // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
    // or if accessing from cloud shell, put "AzureCloud"
    open_external_sources = ["*"]
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

////////////////////////////////////////////////////////////////
// virtual network
////////////////////////////////////////////////////////////////

module "network" {
    source = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location = local.location

    open_external_ports   = local.open_external_ports
    open_external_sources = local.open_external_sources
}

resource "azurerm_subnet" "rendergwsubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = module.network.vnet_resource_group
  virtual_network_name = module.network.vnet_name
  address_prefixes     = ["10.0.0.0/24"]

  depends_on = [module.network.module_depends_on_ids]
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.filer_location
}

resource "azurerm_virtual_network" "filervnet" {
    name                = "filervnet"
    address_space       = ["192.168.0.0/22"]
    location            = azurerm_resource_group.nfsfiler.location
    resource_group_name = azurerm_resource_group.nfsfiler.name
}

resource "azurerm_subnet" "filergwsubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.nfsfiler.name
  virtual_network_name = azurerm_virtual_network.filervnet.name
  address_prefixes     = ["192.168.0.0/24"]
}

////////////////////////////////////////////////////////////////
// netapp
////////////////////////////////////////////////////////////////

resource "azurerm_subnet" "netapp" {
  name                 = "netapp-subnet"
  resource_group_name  = azurerm_resource_group.nfsfiler.name
  virtual_network_name = azurerm_virtual_network.filervnet.name
  address_prefixes     = ["192.168.1.0/24"]

  delegation {
    name = "netapp"

    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_netapp_account" "account" {
  name                = local.netapp_account_name
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
}

resource "azurerm_netapp_pool" "pool" {
  name                = "netapppool"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
  account_name        = azurerm_netapp_account.account.name
  service_level       = local.service_level
  size_in_tb          = local.pool_size_in_tb
}

resource "azurerm_netapp_volume" "netappvolume" {
  name                = "netappvolume"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
  account_name        = azurerm_netapp_account.account.name
  pool_name           = azurerm_netapp_pool.pool.name
  volume_path         = local.export_path
  service_level       = local.service_level
  subnet_id           = azurerm_subnet.netapp.id
  protocols           = ["NFSv3"]
  storage_quota_in_gb = local.volume_storage_quota_in_gb

  export_policy_rule {
    rule_index = 1
    allowed_clients = ["0.0.0.0/0"]
    protocols_enabled = ["NFSv3"]
    unix_read_write = true
  }
}

////////////////////////////////////////////////////////////////
// Per documents NETAPP does not 
// work with vnet peering so we must
// create a VNET to VNET GW described here https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal
////////////////////////////////////////////////////////////////

resource "azurerm_public_ip" "filergwpublicip" {
  name                = "filergwpublicip"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "filervpngw" {
  name                = "filervpngw"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.filergwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.filergwsubnet.id
  }
}

resource "azurerm_public_ip" "rendergwpublicip" {
  name                = "rendergwpublicip"
  location            = local.location
  resource_group_name = module.network.vnet_resource_group

  allocation_method = "Dynamic"

  depends_on = [module.network.vnet_id]
}

resource "azurerm_virtual_network_gateway" "rendervpngw" {
  name                = "rendervpngw"
  location            = local.location
  resource_group_name = module.network.vnet_resource_group

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.rendergwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.rendergwsubnet.id
  }

  depends_on = [azurerm_subnet.filergwsubnet, azurerm_subnet.netapp]
}

resource "azurerm_virtual_network_gateway_connection" "filer_to_render" {
  name                = "filer_to_render"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.filervpngw.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.rendervpngw.id

  shared_key = local.shared_key
}

resource "azurerm_virtual_network_gateway_connection" "render_to_filer" {
  name                = "render_to_filer"
  location            = local.location
  resource_group_name = module.network.vnet_resource_group

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.rendervpngw.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.filervpngw.id

  shared_key = local.shared_key
}

////////////////////////////////////////////////////////////////
// VFXT
////////////////////////////////////////////////////////////////

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    ssh_port = local.ssh_port
    
    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.jumpbox_subnet_name
}

resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    // ssh key takes precedence over controller password
    controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    controller_ssh_port = local.ssh_port
    // terraform is not creating the implicit dependency on the controller module
    // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
    // to work around, add the explicit dependency
    depends_on = [module.vfxtcontroller, azurerm_virtual_network_gateway_connection.render_to_filer, azurerm_virtual_network_gateway_connection.filer_to_render]

    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = local.network_resource_group_name
    azure_network_name = module.network.vnet_name
    azure_subnet_name = module.network.cloud_cache_subnet_name
    vfxt_cluster_name = local.vfxt_cluster_name
    vfxt_admin_password = local.vfxt_cluster_password
    vfxt_ssh_key_data = local.vfxt_ssh_key_data
    vfxt_node_count = 3

    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = join(" ", tolist(azurerm_netapp_volume.netappvolume.mount_ip_addresses))
        cache_policy = local.cache_policy
        junction {
            namespace_path = "/${local.export_path}"
            core_filer_export = "/${local.export_path}"
        }
    }
}

output "netapp_region" {
    value = local.filer_location
}

output "netapp_addresses" {
    value = azurerm_netapp_volume.netappvolume.mount_ip_addresses
}

output "netapp_export" {
    value = local.export_path
}

output "controller_username" {
    value = module.vfxtcontroller.controller_username
}

output "controller_address" {
    value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
    value = "ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "vfxt_region" {
    value = local.location
}

output "vfxt_management_ip" {
    value = avere_vfxt.vfxt.vfxt_management_ip
}

output "vfxt_mount_addresses" {
    value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "vfxt_export_path" {
    value = "/${local.export_path}"
}