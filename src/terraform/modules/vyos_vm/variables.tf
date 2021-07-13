variable "resource_group_name" {
  description = "The existing resource group to contain the VyOS VM."
}

variable "location" {
  description = "The Azure Region into which the VyOS VM will be created."
}

variable "admin_username" {
  description = "Admin username on the VyOS VM."
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the VyOS VM.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the VyOS VM.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "unique_name" {
  description = "(optional) The unique name used for the VyOS VM and for resource names associated with the VM."
  default     = "vyos"
}

variable "vm_size" {
  description = "Size of the VM."
  default     = "Standard_F4s_v2"
}

variable "vyos_image_id" {
  type = string
}

variable "static_private_ip" {
  type = string
}

variable "vnet_rg" {
  description = "The resource group name for the VNET."
}

variable "vnet_name" {
  description = "The unique name used for the virtual network."
}

variable "vnet_subnet_name" {
  description = "The unique name used for the virtual network subnet."
}

variable "tags" {
  description = "specifies key value pairs of tags"
  default     = null
}
