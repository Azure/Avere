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
  default     = "Hammerspace1"
}

variable "admin_username" {
  description = "Admin username on the jumpbox."
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the jumpbox.  If not specified, ssh_key_data needs to be set."
}

variable "dsx_instance_count" {
  description = "How many DSX instances to create as part of this deployment?"
}

variable "dsx_instance_type" {
  description = "DSX Instance Type"
  default     = "Standard_D8s_v3"
}

variable "virtual_network_resource_group" {
  description = "The resource group name for the virtual network."
}

variable "virtual_network_name" {
  description = "The name used for the virtual network."
}

variable "virtual_network_data_subnet_name" {
  description = "The unique name used for the data virtual network subnet."
}

variable "virtual_network_data_subnet_mask_bits" {
  description = "The mask bits of the data subnet (must be the same as anvil)."
}

variable "anvil_password" {
  description = "Anvil Cluster Data IP."
}

variable "anvil_data_cluster_ip" {
  description = "Anvil Cluster Data IP."
}

variable "anvil_domain" {
  description = "The domain used by the anvil nodes."
}

variable "module_depends_on" {
  default     = [""]
  description = "depends on workaround discussed in https://discuss.hashicorp.com/t/tips-howto-implement-module-depends-on-emulation/2305/2"
}

////////////////////////////////////////////////////////////////
// Advanced Configuration
////////////////////////////////////////////////////////////////

variable "dsx_boot_disk_storage_type" {
  description = "DSX Boot/OS Disk Storage Type (Default is Premium_LRS if supported by the instance type, otherwise Standard_LRS)"
  default     = "StandardSSD_LRS"
  // options:
  // "Standard_LRS",
  // "Premium_LRS",
  // "StandardSSD_LRS"
}

variable "dsx_boot_disk_size" {
  description = "DSX Boot/OS Disk Size"
  default     = 127
}

variable "dsx_data_disk_storage_type" {
  description = "DSX data disk Storage Type (Default is Premium_LRS if supported by the instance type, otherwise Standard_LRS))"
  default     = "Premium_LRS"
  // options:
  // "Standard_LRS",
  // "Premium_LRS",
  // "StandardSSD_LRS"
}

variable "dsx_data_disk_size" {
  description = "DSX data disk Size"
  default     = 255
}
