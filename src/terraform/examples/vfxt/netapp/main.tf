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

    // network details
    network_resource_group_name = "network_resource_group"
    
    // netapp filer details
    netapp_resource_group_name = "netapp_resource_group"
    export_path = "data"
    // possible values are Standard, Premium, Ultra
    service_level = "Premium"
    pool_size_in_tb = 4
    volume_storage_quota_in_gb = 100
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    // if you are running a locked down network, set controller_add_public_ip to false
    controller_add_public_ip = true
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "VFXT_PASSWORD"
    // vfxt cache polies
    //  "Clients Bypassing the Cluster"
    //  "Read Caching"
    //  "Read and Write Caching"
    //  "Full Caching"
    //  "Transitioning Clients Before or After a Migration"
    cache_policy = "Clients Bypassing the Cluster"

    // advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
    controller_image_id = null
    vfxt_image_id       = null
    // advanced scenario: put the custom image resource group here
    alternative_resource_groups = []
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

// the render network
module "network" {
    source = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location = local.location
}

resource "azurerm_subnet" "netapp" {
  name                 = "netapp-subnet"
  resource_group_name  = module.network.vnet_resource_group
  virtual_network_name = module.network.vnet_name
  address_prefixes     = ["10.0.255.0/24"]

  delegation {
    name = "netapp"

    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  depends_on = [module.network]
}

resource "azurerm_resource_group" "netapprg" {
  name     = local.netapp_resource_group_name
  location = local.location
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [module.network]
}

resource "azurerm_netapp_account" "account" {
  name                = "netappaccount"
  location            = azurerm_resource_group.netapprg.location
  resource_group_name = azurerm_resource_group.netapprg.name
}

resource "azurerm_netapp_pool" "pool" {
  name                = "netapppool"
  location            = azurerm_resource_group.netapprg.location
  resource_group_name = azurerm_resource_group.netapprg.name
  account_name        = azurerm_netapp_account.account.name
  service_level       = local.service_level
  size_in_tb          = local.pool_size_in_tb
}

locals {
    // values may be Standard, Premium, Ultra
    storage_quota_in_bytes = local.volume_storage_quota_in_gb * 1024 * 1024 * 1024
    // full definition here: https://docs.microsoft.com/en-us/azure/templates/microsoft.netapp/2019-06-01/netappaccounts/capacitypools/volumes
    arm_template = templatefile("volume.json",
    {
        netappaccount       = azurerm_netapp_account.account.name,
        netapppool          = azurerm_netapp_pool.pool.name,
        netappvolume        = "netappvolume"
        location            = azurerm_resource_group.netapprg.location,
        export_path         = local.export_path
        service_level       = local.service_level
        subnet_id           = azurerm_subnet.netapp.id
        storage_quota_in_bytes = local.storage_quota_in_bytes
    })
}

// The only way to destroy a template deployment is to destroy the associated
// RG, so keep each netapp filer template unique to its RG. 
resource "azurerm_template_deployment" "netappvolume" {
  name                = "netappvolumetmpl"
  resource_group_name = azurerm_resource_group.netapprg.name
  deployment_mode     = "Incremental"
  template_body       = local.arm_template
}

/*
Due to bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/5416, we are unable to get the mount_adress to pass on, and therefor need template
resource "azurerm_netapp_volume" "volume" {
  lifecycle {
    prevent_destroy = true
  }

  name                = "example-netappvolume"
  location            = azurerm_resource_group.netapprg.location
  resource_group_name = azurerm_resource_group.netapprg.name
  account_name        = azurerm_netapp_account.account.name
  pool_name           = azurerm_netapp_pool.pool.name
  volume_path         = local.export_path
  service_level       = "Premium"
  subnet_id           = azurerm_subnet.netapp.id
  protocols           = ["NFSv3"]
  storage_quota_in_gb = 100
}*/

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    image_id = local.controller_image_id
    alternative_resource_groups = local.alternative_resource_groups

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.jumpbox_subnet_name

    module_depends_on = [module.network.vnet_id]
}

// the vfxt
resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    // ssh key takes precedence over controller password
    controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    // terraform is not creating the implicit dependency on the controller module
    // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
    // to work around, add the explicit dependency
    depends_on = [module.vfxtcontroller]
    
    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = local.network_resource_group_name
    azure_network_name = module.network.vnet_name
    azure_subnet_name = module.network.cloud_cache_subnet_name
    vfxt_cluster_name = local.vfxt_cluster_name
    vfxt_admin_password = local.vfxt_cluster_password
    vfxt_node_count = 3
    image_id = local.vfxt_image_id

    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = azurerm_template_deployment.netappvolume.outputs["mountIpAddress"]
        cache_policy = local.cache_policy
        junction {
            namespace_path = "/datacache"
            core_filer_export = "/${local.export_path}"
        }
        /* add additional junctions by adding another junction block shown below
        junction {
            namespace_path = "/nfsdata2"
            core_filer_export = "/data2"
        }
        */
    }
} 

output "netapp_export_path" {
    value = local.export_path
}

output "netapp_mount_ip_address" {
    value = azurerm_template_deployment.netappvolume.outputs["mountIpAddress"]
}

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
    value = "ssh -L443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
    value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
    value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}