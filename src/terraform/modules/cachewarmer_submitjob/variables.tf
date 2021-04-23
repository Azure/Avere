variable "deploy_cachewarmer" {
  description = "specifies to create the cachewarmer or not"
  default     = true
}

variable "node_address" {
  description = "The address of controller or jumpbox"
}

variable "admin_username" {
  description = "Admin username on the controller or jumpbox"
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the controller or jumpbox.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the controller or jumpbox.  If not specified, the password needs to be set.  The ssh_key_data takes precedence over the password, and if set, the password will be ignored."
}

variable "ssh_port" {
  description = "specifies the tcp port to use for ssh"
  default     = 22
}

variable "storage_account" {
  description = "the storage account holding the queue"
}

variable "storage_key" {
  description = "the storage key"
}

variable "queue_name_prefix" {
  description = "the queue name prefix for the job management"
}

variable "warm_mount_addresses" {
  description = "the warm target cache filer mount addresses separated by comma"
}

variable "warm_target_export_path" {
  description = "the warm target export path"
}

variable "warm_target_path" {
  description = "the target path to warm"
}

variable "block_until_warm" {
  description = "block the operation until the cache warming has finished"
  default     = true
}

variable "module_depends_on" {
  default     = [""]
  description = "depends on workaround discussed in https://discuss.hashicorp.com/t/tips-howto-implement-module-depends-on-emulation/2305/2"
}
