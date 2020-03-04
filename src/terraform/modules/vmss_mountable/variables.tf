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
}
variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the jumpbox.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "unique_name" {
  description = "The unique name used for the jumpbox and for resource names associated with the VM."
  default = "jumpbox"
}

variable "vm_count" {
  description = "The number of vms to create and can be values of 1 to 1000."
  default = 2
}

variable "vm_size" {
  description = "Size of the VM."
  default = "Standard_DS2_v2"
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

variable "mount_target" {
  description = "the path on vmss where the nfs share will be mounted"
  default = false
}

variable "nfs_export_addresses" {
  description = "An array of mount addresses where one will be chosen for the mount host.  If using DNS round robin, specify a single element array with the dns name."
}

variable "nfs_export_path" {
  description = "the nfs export to mount to the mount target on the VMSS node"
}

variable "nfs_export_path" {
  description = "the nfs export to mount to the mount target on the VMSS node"
}

variable "bootstrap_script_path" {
  description = "The script path on the NFS share to execute during deployment."
}
