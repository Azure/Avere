variable "resource_group_name" {
  description = "The resource group to contain the NFS filer."
}

variable "location" {
    description = "The Azure Region into which all resources of NFS filer will be created."
}

variable "admin_username" {
  description = "Admin username on the VM."
  default = "azureuser"
}

variable "ssh_key_data" {
  description = "The public SSH key used for access to the VM."
}

variable "unique_name" {
  description = "The unique name used for the VM and for resource names associated with the VM."
  default = "cloudnfsfiler"
}

variable "vm_size" {
  description = "Size of the VM."
  default = "Standard_L32s"
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

variable "nfs_export_path" {
  description = "The nfs export path exposed in /etc/exports."
  default = "/data"
}

variable "nfs_export_options" {
  description = "The mount options used in /etc/exports."
  default = "*(rw,sync,no_root_squash)"
}