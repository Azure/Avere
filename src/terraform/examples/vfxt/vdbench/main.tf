variable "location" {
  description = "sets the region"
}

variable "vmss_resource_group_name" {
  description = "sets the vmss resource group name"
}

variable "controller_address" {
  description = "sets the controller address"
}

variable "controller_username" {
  description = "sets the admin username of the controller"
}

variable "ssh_key_data" {
  description = "sets the ssh_key_data of the controller"
}

variable "vserver_ip_addresses" {
  type        = list(string)
  description = "sets the vserver ip addresses"
}

variable "nfs_export_path" {
  description = "sets the nfs_export_path"
}

variable "vdbench_url" {
  description = "sets the vdbench url"
}

variable "vnet_resource_group" {
  description = "sets the vnet resource group name"
}

variable "vnet_name" {
  description = "sets the vnet name"
  default     = "rendervnet"
}

variable "subnet_name" {
  description = "sets the subnet name"
  default     = "render_clients1"
}

variable "ssh_port" {
  description = "ssh port"
  default     = 22
}

variable "vm_count" {
  description = "number of instances created in VMSS"
  default     = 12
}

// customize the simple VM by editing the following local variables
locals {
  unique_name  = "vmss"
  vmss_size    = "Standard_D2s_v3"
  mount_target = "/data"
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// the vdbench module
module "vdbench_configure" {
  source = "github.com/Azure/Avere/src/terraform/modules/vdbench_config"

  node_address    = var.controller_address
  admin_username  = var.controller_username
  ssh_key_data    = var.ssh_key_data
  nfs_address     = tolist(var.vserver_ip_addresses)[0]
  nfs_export_path = var.nfs_export_path
  vdbench_url     = var.vdbench_url
  ssh_port        = var.ssh_port
}

// the VMSS module
module "vmss" {
  source = "github.com/Azure/Avere/src/terraform/modules/vmss_mountable"

  resource_group_name            = var.vmss_resource_group_name
  location                       = var.location
  admin_username                 = var.controller_username
  ssh_key_data                   = var.ssh_key_data
  unique_name                    = local.unique_name
  vm_count                       = var.vm_count
  vm_size                        = local.vmss_size
  virtual_network_resource_group = var.vnet_resource_group
  virtual_network_name           = var.vnet_name
  virtual_network_subnet_name    = var.subnet_name
  mount_target                   = local.mount_target
  nfs_export_addresses           = tolist(var.vserver_ip_addresses)
  nfs_export_path                = var.nfs_export_path
  bootstrap_script_path          = module.vdbench_configure.bootstrap_script_path
  depends_on = [
    module.vdbench_configure,
  ]
}

output "vmss_id" {
  value = module.vmss.vmss_id
}

output "vmss_resource_group" {
  value = module.vmss.vmss_resource_group
}

output "vmss_name" {
  value = module.vmss.vmss_name
}

output "vmss_addresses_command" {
  // local-exec doesn't return output, and the only way to
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${module.vmss.vmss_resource_group} --vmss-name ${module.vmss.vmss_name} --query [].ipConfigurations[].privateIpAddress"
}
