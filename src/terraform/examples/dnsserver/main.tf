// customize the simple VM by adjusting the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "PASSWORD"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
    ssh_port = 22

    // network details, the server is deployed to the network resource group
    vnet_resource_group_name = "network_resource_group"
    vnet_name = "rendervnet"
    vnet_subnet_name = "cloud_cache"
    
    // it is recommended to set the ip address at a static ip address
    dnsserver_static_ip = null // "10.0.1.253"
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

module "dnsserver" {
    source = "github.com/Azure/Avere/src/terraform/modules/dnsserver"
    resource_group_name = local.vnet_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.dnsserver_add_public_ip
    ssh_port = local.ssh_port

    // network details
    virtual_network_resource_group = local.vnet_resource_group_name
    virtual_network_name = local.vnet_name
    virtual_network_subnet_name = local.vnet_subnet_name

    private_ip_address = local.dnsserver_static_ip

    module_depends_on = []
}

output "dnsserver_username" {
  value = module.dnsserver.dnsserver_username
}

output "dnsserver_address" {
  value = module.dnsserver.dnsserver_address
}

output "ssh_command" {
    value = "ssh ${module.dnsserver.dnsserver_username}@${module.dnsserver.dnsserver_address}"
}