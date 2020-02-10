variable "resource_group_name" {
  description = "The resource group to contain the controller."
}

variable "location" {
    description = "The Azure Region into which the controller will be created."
}

variable "admin_username" {
  description = "Admin username on the controller."
  default = "azureuser"
}

variable "ssh_key_data" {
  description = "The public SSH key used for access to the controller."
}

variable "unique_name" {
  description = "The unique name used for the controller and for resource names associated with the VM."
  default = "controller"
}

variable "vm_size" {
  description = "Size of the VM."
  default = "Standard_A1_v2"
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
  description = "specifies if the controller should have a publice ip"
  default = false
}