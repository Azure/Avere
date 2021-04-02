// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location       = "westus2"
    resource_group = "windowsgridgpu"
   
    admin_username = "azureuser"
    admin_password = "ReplacePassword$"
   
    vm_size        = "Standard_NV6"
    // populate with the custom managed image id, and 
    image_id       = "" 

    // update the below with information about the domain
    ad_domain   = "" // example "rendering.com"
    // leave blank to add machine to default location
    ou_path     = ""
    ad_username = "" 
    ad_password = ""

    // specify 'Windows_Client' to specifies the type of on-premise 
    // license (also known as Azure Hybrid Use Benefit 
    // https://azure.microsoft.com/en-us/pricing/hybrid-benefit/faq/) 
    // which should be used for this Virtual Machine.
    license_type = "None"
    
    teradici_license_key = ""
    
    // network details
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name           = "rendervnet"
    virtual_network_subnet_name    = "jumpbox"

    unique_name = "wingrid"
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

resource "azurerm_resource_group" "windowsgridgpu" {
  name     = local.resource_group
  location = local.location
}

module "windowsgridgpu" {
    source               = "github.com/Azure/Avere/src/terraform/modules/windowsgridgpu"
    resource_group_name  = local.resource_group
    location             = local.location
    admin_username       = local.admin_username
    admin_password       = local.admin_password
    vm_size              = local.vm_size
    license_type         = local.license_type
    teradici_license_key = local.teradici_license_key
    image_id             = local.image_id
    install_pcoip        = false

    ad_domain   = local.ad_domain
    ou_path     = local.ou_path
    ad_username = local.ad_username 
    ad_password = local.ad_password

    // network details
    virtual_network_resource_group = local.virtual_network_resource_group
    virtual_network_name           = local.virtual_network_name
    virtual_network_subnet_name    = local.virtual_network_subnet_name

    module_depends_on = [azurerm_resource_group.windowsgridgpu.id]
}

output "address" {
  value = module.windowsgridgpu.address
}