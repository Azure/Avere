variable "resource_group_name" {
  description = "The existing resource group to contain the dnsserver."
}

variable "location" {
  description = "The Azure Region into which the dnsserver will be created."
}

variable "admin_username" {
  description = "Admin username on the dnsserver."
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the dnsserver.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the dnsserver.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "ssh_port" {
  description = "specifies the tcp port to use for ssh"
  default     = 22
}

variable "unique_name" {
  description = "The unique name used for the dnsserver and for resource names associated with the VM."
  default     = "nfsbridge"
}

variable "vm_size" {
  description = "Size of the VM."
  default     = "Standard_F32s_v2"
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

variable "private_ip_address" {
  description = "specifies a static private ip address to use"
  default     = null
}
