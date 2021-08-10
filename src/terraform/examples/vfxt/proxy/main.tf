////////////////////////////////////////////////////////////////////////////////////////
// WARNING: if you get an error deploying, please review https://aka.ms/avere-tf-prereqs
////////////////////////////////////////////////////////////////////////////////////////
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

  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  ssh_source_ip = "*"

  // proxy details
  proxy_resource_group_name = "proxy_resource_group"

  // network details
  network_resource_group_name = "network_resource_group"

  // nfs filer details
  filer_resource_group_name = "filer_resource_group"

  // storage details
  storage_resource_group_name  = "storage_resource_group"
  storage_account_name         = "storageaccount"
  avere_storage_container_name = "vfxt"

  // vfxt details
  vfxt_resource_group_name = "vfxt_resource_group"
  // if you are running a locked down network, set controller_add_public_ip to false
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  vfxt_ssh_key_data        = local.vm_ssh_key_data
  namespace_path           = "/nfs1data"
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
  // advanced scenario: in addition to storage account put the custom image resource group here
  alternative_resource_groups = [local.storage_resource_group_name]
  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [local.ssh_port, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
  peer_vnet_rg          = ""
  peer_vnet_name        = ""
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = ">=1.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// the render network
module "network" {
  source                    = "github.com/Azure/Avere/src/terraform/modules/render_network_secure"
  resource_group_name       = local.network_resource_group_name
  location                  = local.location
  ssh_source_address_prefix = local.ssh_source_ip

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources
  peer_vnet_rg          = local.peer_vnet_rg
  peer_vnet_name        = local.peer_vnet_name
}

resource "azurerm_resource_group" "proxy" {
  name     = local.proxy_resource_group_name
  location = local.location
}

module "proxy" {
  source              = "github.com/Azure/Avere/src/terraform/modules/proxy"
  resource_group_name = azurerm_resource_group.proxy.name
  location            = local.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.proxy_subnet_name

  depends_on = [
    azurerm_resource_group.proxy,
    module.network,
  ]
}

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    virtual_network_subnet_ids = [
      module.network.cloud_cache_subnet_id,
      module.network.jumpbox_subnet_id,
    ]
    default_action = "Deny"
  }
  // if the nsg associations do not complete before the storage account
  // create is started, it will fail with "subnet updating"
  depends_on = [
    module.network,
  ]
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

// the ephemeral filer
module "nasfiler1" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.nfsfiler.name
  location            = azurerm_resource_group.nfsfiler.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = "Standard_D2s_v3"
  unique_name         = "nasfiler1"
  proxy               = "http://${module.proxy.address}:3128"

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.cloud_filers_subnet_name

  depends_on = [
    azurerm_resource_group.nfsfiler,
    module.network,
  ]
}

// the vfxt controller
module "vfxtcontroller" {
  source                      = "github.com/Azure/Avere/src/terraform/modules/controller3"
  resource_group_name         = local.vfxt_resource_group_name
  location                    = local.location
  admin_username              = local.vm_admin_username
  admin_password              = local.vm_admin_password
  ssh_key_data                = local.vm_ssh_key_data
  add_public_ip               = local.controller_add_public_ip
  image_id                    = local.controller_image_id
  alternative_resource_groups = local.alternative_resource_groups
  ssh_port                    = local.ssh_port

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    module.network,
  ]
}

// the vfxt
resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = module.vfxtcontroller.controller_username
  // ssh key takes precedence over controller password
  controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
  controller_ssh_port       = local.ssh_port

  location                     = local.location
  azure_resource_group         = local.vfxt_resource_group_name
  azure_network_resource_group = local.network_resource_group_name
  azure_network_name           = module.network.vnet_name
  azure_subnet_name            = module.network.cloud_cache_subnet_name
  vfxt_cluster_name            = local.vfxt_cluster_name
  vfxt_admin_password          = local.vfxt_cluster_password
  vfxt_ssh_key_data            = local.vfxt_ssh_key_data
  vfxt_node_count              = 3
  ntp_servers                  = "169.254.169.254"
  proxy_uri                    = "http://${module.proxy.address}:3128"
  cluster_proxy_uri            = "http://${module.proxy.address}:3128"
  image_id                     = local.vfxt_image_id

  azure_storage_filer {
    account_name            = azurerm_storage_account.storage.name
    container_name          = local.avere_storage_container_name
    junction_namespace_path = "/storagevfxt"
  }

  core_filer {
    name               = "nfs1"
    fqdn_or_primary_ip = module.nasfiler1.primary_ip
    cache_policy       = local.cache_policy
    junction {
      namespace_path    = local.namespace_path
      core_filer_export = module.nasfiler1.core_filer_export
    }
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller and proxy at the
  // same time as vfxt cluster to work around, add the explicit dependencies
  depends_on = [
    module.vfxtcontroller,
    module.proxy,
  ]
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

output "management_ip" {
  value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
  value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "mount_namespace_path" {
  value = local.namespace_path
}
