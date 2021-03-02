variable "resource_group_name" {
  description = "The existing resource group to contain the jumpbox."
}

variable "location" {
  description = "The Azure Region into which the jumpbox will be created."
}

variable "hammerspace_image_id" {
  description = "The hammerspace image id provided by Hammerspace."
}

variable "unique_name" {
  description = "The unique name used for the hammerspace node."
  default = "Hammerspace1"
}

variable "admin_username" {
  description = "Admin username on the jumpbox."
  default = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the jumpbox.  If not specified, ssh_key_data needs to be set."
}

variable "anvil_configuration" {
  description = "'High Availability' (2 nodes), 'Standalone' (1 node) Anvil metadata server"
  default = "Standalone"
  // "High Availability"
}

variable "anvil_instance_type" {
  description = "Anvil Metadata Server Instance Type"
  default = "Standard_D8s_v3"
}

variable "virtual_network_resource_group" {
  description = "The resource group name for the virtual network."
}

variable "virtual_network_name" {
  description = "The name used for the virtual network."
}

variable "virtual_network_ha_subnet_name" {
  description = "The unique name used for the ha virtual network subnet."
}

variable "virtual_network_data_subnet_name" {
  description = "The unique name used for the data virtual network subnet."
}

variable "module_depends_on" {
  default = [""]
  description = "depends on workaround discussed in https://discuss.hashicorp.com/t/tips-howto-implement-module-depends-on-emulation/2305/2"
}

////////////////////////////////////////////////////////////////
// Advanced Configuration
////////////////////////////////////////////////////////////////

variable "anvil_data_cluster_ip" {
  description = "High Availability Anvil Cluster IP on the Data Subnet, or leave blank to get dynamic address."
  default = ""
}

variable "ntp_server" {
  description = "The ntp server to be used by Hammerspace."
  default = "time.windows.com"
  // two alternatives:
  // ntp_server = "169.254.169.254"
  // ntp_server = "pool.ntp.org"
}

variable "anvil_boot_disk_storage_type" {
  description = "Anvil Boot/OS Disk Storage Type (Default is Premium_LRS if supported by the instance type, otherwise StandardSSD_LRS)"
  default = "StandardSSD_LRS"
  // options:
  // "Standard_LRS",
  // "Premium_LRS",
  // "StandardSSD_LRS"
}

variable "anvil_boot_disk_size" {
  description = "Anvil Boot/OS Disk Size"
  default = 127
}

variable "anvil_metadata_disk_storage_type" {
  description = "Anvil Boot/OS Disk Storage Type (Default is Premium_LRS if supported by the instance type, otherwise StandardSSD_LRS)"
  default = "Premium_LRS"
  // options:
  // "Standard_LRS",
  // "Premium_LRS",
  // "StandardSSD_LRS"
}

variable "anvil_metadata_disk_size" {
  description = "Anvil Metadata Disk Size"
  default = 255
}
