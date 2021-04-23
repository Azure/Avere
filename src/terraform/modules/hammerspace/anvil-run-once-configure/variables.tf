variable "anvil_arm_virtual_machine_id" {
  description = "the ARM url to the virtual machine"
}

variable "anvil_data_cluster_ip" {
  description = "High Availability Anvil Cluster IP on the Data Subnet, or leave blank to get dynamic address."
}

variable "web_ui_password" {
  description = "the anvil password."
}

variable "dsx_count" {
  description = "the count of dsx nodes."
}

variable "nfs_export_path" {
  description = "the nfs export path to export from the Hammerspace filer, leave blank to not set"
  default     = ""
}

variable "local_site_name" {
  description = "the local site name, leave blank to not set"
  default     = ""
}

variable "ad_domain" {
  description = "the ad domainname, leave blank to not set"
  default     = ""
}

variable "ad_user" {
  description = "the ad user, leave blank to not set"
  default     = ""
}

variable "ad_user_password" {
  description = "the ad user password, leave blank to not set"
  default     = ""
}

variable "azure_storage_account" {
  description = "the azure storage account name"
  default     = ""
}

variable "azure_storage_account_key" {
  description = "the azure storage account key"
  default     = ""
}

variable "azure_storage_account_container" {
  description = "the azure storage account container"
  default     = ""
}

variable "anvil_hostname" {
  description = "the anvil hostname"
}

variable "module_depends_on" {
  default     = [""]
  description = "depends on workaround discussed in https://discuss.hashicorp.com/t/tips-howto-implement-module-depends-on-emulation/2305/2"
}
