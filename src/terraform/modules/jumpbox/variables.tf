variable "resource_group_name" {
  description = "The existing resource group to contain the jumpbox."
}

variable "location" {
    description = "The Azure Region into which the jumpbox will be created."
}

variable "admin_username" {
  description = "Admin username on the jumpbox."
  default = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the jumpbox.  If not specified, ssh_key_data needs to be set."
  default = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the jumpbox.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "unique_name" {
  description = "The unique name used for the jumpbox and for resource names associated with the VM."
  default = "jumpbox"
}

variable "vm_size" {
  description = "Size of the VM."
  default = "Standard_D2s_v3"
}

variable "virtual_network_resource_group" {
  description = "The resource group name for the VNET."
}

variable "virtual_network_name" {
  description = "The unique name used for the virtual network."
}

variable "virtual_network_subnet_name" {
  description = "The unique name used for the virtual network subnet."
}

variable "add_public_ip" {
  description = "specifies if the jumpbox should have a publice ip"
  default = false
}

variable "build_vfxt_terraform_provider" {
  description = "specifies if the jumpbox should build the terraform provider"
  default = true
}

variable "alternative_resource_groups" {
  description = "specifies alternative resource groups including those containing custom images or storage accounts"
  default = []
}