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
  vm_ssh_key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+lj5pn0geF6kyf1vxKfHLy/MlFOtdlhyrqdwQkw+JLhzbu2FXY/1gHpfk2Sag+1f6+yLzPww1E3Zxl46y9F/JVYyX2ZuSMmIJ+Zjy2oi8bIPIwOM3W/rt82Pcya5BAzI+HtswMR8IYclLb7mWxuiv4lyY7vsIF3OQbSAdcJ4nmFW409LEBNtKMdSKHZ3XukTqDPiIa1IjYLnzGT2qlY+aHk1ju++LCy+6u0YZYorak9HTQ47GgDraR7lTybxJYp1nRMkKAtU5ILjY/vcDD/9K0TSeeSu+eZp51O8gmfpjcQatd5kdwH2UqzpEksvlgiT4P/oTRqfjtqWW5TOivCBOqH5a2Qx44Sg9IUy+ckxLh/2h6NaIt8SlXhU+rGNBa57ywS7A2N4xTJXDPOHLtNLKYlLks+1NR1LX9zVJcuDh0lJrehQBDiOpS5HUGewNb2PzLjiWgkq44oqiljbIh3iUANxN3+DOUDz1HeV+B3fnNTI6gkL9J7R0U30KlDjMk0E= eoinbailey@RANDOM-RIHO"
  ssh_port        = 2022

  // network details
  network_resource_group_name = "smb_test_network_resource_group"

  // storage details
  storage_resource_group_name  = "pre_pop_storage_resource_group"
  storage_account_name         = "prepopopencue"
  avere_storage_container_name = "vfxt"

  // vfxt details
  vfxt_resource_group_name = "smb_test_vfxt_resource_group"
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  vfxt_ssh_key_data        = local.vm_ssh_key_data
  namespace_path           = "/storagevfxt"

  // advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
  controller_image_id = null
  vfxt_image_id       = null
  // advanced scenario: in addition to storage account put the custom image resource group here
  alternative_resource_groups = [local.storage_resource_group_name]
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
  virtual_network_name           = "rendervnet"
  virtual_network_subnet_name    = "jumpbox"
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
  azure_network_name           = "rendervnet"
  azure_subnet_name            = "cloud_cache"
  vfxt_cluster_name            = local.vfxt_cluster_name
  vfxt_admin_password          = local.vfxt_cluster_password
  vfxt_ssh_key_data            = local.vfxt_ssh_key_data
  vfxt_node_count              = 5
  image_id                     = local.vfxt_image_id

  # Test vFXT sku size
  node_size = "unsupported_test_SKU"
  node_cache_size = 1024

  azure_storage_filer {
    account_name            = local.storage_account_name
    container_name          = local.avere_storage_container_name
    custom_settings         = []
    junction_namespace_path = local.namespace_path
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller,
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