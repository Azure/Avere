// customize the simple VM by editing the following local variables
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
  ssh_port        = 22

  // network details
  network_resource_group_name = "network_resource_group"
  vnet_name                   = "rendernetwork"
  subnet_name                 = "cache"

  // dns settings
  // A space separated list of dns servers to forward to
  onprem_dns_servers  = "169.254.169.254"
  dnsserver_static_ip = "10.0.3.253"
  onprem_filer_fqdn   = "nfs1.rendering.com"
  dns_max_ttl_seconds = 300

  avere_first_ip      = "10.0.3.50"
  avere_ip_addr_count = 3
}

terraform {
  required_version = ">= 0.14.0"
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

module "dnsserver" {
  source              = "github.com/Azure/Avere/src/terraform/modules/dnsserver"
  resource_group_name = local.network_resource_group_name
  location            = local.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  ssh_port            = local.ssh_port

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = local.vnet_name
  virtual_network_subnet_name    = local.subnet_name

  // this is the address of the unbound dns server
  private_ip_address = local.dnsserver_static_ip

  dns_server          = local.onprem_dns_servers
  avere_first_ip_addr = local.avere_first_ip
  avere_ip_addr_count = local.avere_ip_addr_count
  avere_filer_fqdn    = local.onprem_filer_fqdn

  // set the TTL
  dns_max_ttl_seconds = local.dns_max_ttl_seconds
}

output "unbound_dns_server_ip" {
  value = module.dnsserver.dnsserver_address
}
