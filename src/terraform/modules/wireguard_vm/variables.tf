variable "resource_group_name" {
  description = "The existing resource group to contain the wireguard VM."
}

variable "location" {
  description = "The Azure Region into which the wireguard VM will be created."
}

variable "admin_username" {
  description = "Admin username on the wireguard VM."
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the wireguard VM.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the wireguard VM.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "unique_name" {
  description = "(optional) The unique name used for the wireguard VM and for resource names associated with the VM."
  default     = "wireguard"
}

variable "vm_size" {
  description = "Size of the VM."
  default     = "Standard_F2s_v2"
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
