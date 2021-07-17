variable "jumpbox_address" {
  description = "The address of controller or jumpbox"
}

variable "jumpbox_username" {
  description = "The username on the controller or jumpbox"
  default     = "azureuser"
}

variable "jumpbox_password" {
  description = "(optional) The password used for access to the controller or jumpbox.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "jumpbox_ssh_key_data" {
  description = "(optional) The public SSH key used for access to the controller or jumpbox.  If not specified, the password needs to be set.  The ssh_key_data takes precedence over the password, and if set, the password will be ignored."
  default     = null
}

variable "jumpbox_ssh_port" {
  description = "specifies the tcp port to use for ssh"
  default     = 22
}

variable "bootstrap_mount_address" {
  description = "the mount address that hosts the worker bootstrap script"
}

variable "bootstrap_export_path" {
  description = "the export path that hosts the worker bootstrap script"
}

variable "bootstrap_subdir" {
  description = "the subdirectory containing the cachewarmer bootstrap scripts"
  default     = "/bootstrap"
}

variable "build_cachewarmer" {
  description = "specify to build the cachewarmer, otherwise it will be downloaded from the release site"
  type        = bool
  default     = false
}
