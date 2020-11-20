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

variable "admin_password" {
  description = "(optional) The password used for access to the vm.  If not specified, ssh_key_data needs to be set."
  default = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the vm.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "unique_name" {
  description = "The unique name used for the VM and for resource names associated with the VM."
  default = "cloudnfsfiler"
}

variable "vm_size" {
  description = "Size of the VM."
  default = "Standard_D14_v2"
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

variable "managed_disk_id" {
  description = "The managed disk id for attaching to the VM."
}

variable "nfs_export_path" {
  description = "The nfs export path exposed in /etc/exports."
  default = "/data"
}

variable "nfs_export_options" {
  description = "The mount options used in /etc/exports."
  default = "*(rw,sync,no_root_squash)"
}

variable "caching" {
  description = "The disk caching options.  A disk above 4095 must be specified as None"
  default = "None"
}

variable "enable_root_login" {
  description = "Enable the root login.  This is sometimes useful for running rsync. Requires ssh_key_data to be set"
  default = false
}

variable "deploy_diagnostic_tools" {
  description = "Enable performance diagnostic tools iotop, bwm-ng, iperf3."
  default = false
}

variable "proxy" {
  description = "specify a proxy address if one exists in the format of http://PROXY_SERVER:PORT"
  default = null
}