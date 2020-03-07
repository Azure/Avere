// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // virtual network and subnet details
    network_resource_group_name  = "network_resource_group"
    virtual_network_name         = "rendervnet"
    subnet_name                  = "cloud_filers"

    // nfs filer details
    filer_resource_group_name = "filer_resource_group"

    // The size performance characteristics are summarized in the README.md.
    // vm_size = "Standard_D2s_v3"
    // vm_size = "Standard_L4s"
    // vm_size = "Standard_L8s"
    // vm_size = "Standard_L16s"
    // vm_size = "Standard_L32s"
    // vm_size = "Standard_L8s_v2"
    // vm_size = "Standard_L16s_v2"
    // vm_size = "Standard_L32s_v2"
    // vm_size = "Standard_L48s_v2"
    // vm_size = "Standard_L64s_v2"
    // vm_size = "Standard_L80s_v25"
    // vm_size = "Standard_M128s"
    vm_size = "Standard_L32s_v2"
}

provider "azurerm" {
    version = "~>2.0.0"
    features {}
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

// the ephemeral filer
module "nfsfiler" {
    source = "../../modules/nfs_filer"
    resource_group_name = azurerm_resource_group.nfsfiler.name
    location = azurerm_resource_group.nfsfiler.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = local.vm_size
    unique_name = "nfsfiler"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = local.virtual_network_name
    virtual_network_subnet_name = local.subnet_name
}
output "nfsfiler_username" {
  value = module.nfsfiler.admin_username
}

output "nfsfiler_address" {
  value = module.nfsfiler.primary_ip
}

output "ssh_string" {
    value = module.nfsfiler.ssh_string
}