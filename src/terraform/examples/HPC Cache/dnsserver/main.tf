// customize the HPC Cache by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    
    // hpc cache details
    hpc_cache_resource_group_name = "hpc_cache_resource_group"

    // HPC Cache Throughput SKU - 3 allowed values for throughput (GB/s) of the cache
    //    Standard_2G
    //    Standard_4G
    //    Standard_8G
    cache_throughput = "Standard_2G"

    // HPC Cache Size - 5 allowed sizes (GBs) for the cache
    //     3072
    //     6144
    //    12288
    //    24576
    //    49152
    cache_size = 12288

    // unique name for cache
    cache_name = "uniquename"
    network_resource_group_name = "network_resource_group"
    virtual_network_name        = "rendervnet"
    virtual_network_subnet_name = "cloud_cache"
    
    // nfs filer related variables
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    dnsserver_static_ip         = "10.0.1.250" // the address of the dns server or leave blank to dynamically assign
    onprem_dns_servers          = "10.0.3.254 169.254.169.254 " // space separated list
    onprem_filer_fqdn           = "nfs1.rendering.com" // the name of the filer to spoof
}

terraform {
	required_providers {
		azurerm = {
			source  = "hashicorp/azurerm"
			version = "~>2.12.0"
		}
	}
}

provider "azurerm" {
	features {}
}

data "azurerm_subnet" "cachesubnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.network_resource_group_name
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = azurerm_subnet.cachesubnet.id
  sku_name            = local.cache_throughput
}

module "dnsserver" {
    source              = "github.com/Azure/Avere/src/terraform/modules/dnsserver"
    resource_group_name = local.network_resource_group_name
    location            = local.location
    admin_username      = local.vm_admin_username
    admin_password      = local.vm_admin_password
    ssh_key_data        = local.vm_ssh_key_data

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name           = local.virtual_network_name
    virtual_network_subnet_name    = local.virtual_network_subnet_name

    // this is the address of the unbound dns server
    private_ip_address  = local.dnsserver_static_ip

    dns_server         = local.onprem_dns_servers
    avere_address_list = azurerm_hpc_cache.hpc_cache.mount_addresses
    avere_filer_fqdn   = local.onprem_filer_fqdn
    excluded_subnet_cidrs = azurerm_subnet.cachesubnet.address_prefixes
    
    // set the TTL
    dns_max_ttl_seconds = 300
}

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "unbound_dns_server_ip" {
  value = module.dnsserver.dnsserver_address
}