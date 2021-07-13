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

variable "nfsfiler_address" {
  description = "the address of the nfs filer"
}

variable "nfsfiler_export_path" {
  description = "the target path of the nfs filer"
}

variable "island_animation_sas_url" {
  description = "the storage account holding the queue"
}

variable "island_basepackage_sas_url" {
  description = "the storage account holding the queue"
}

variable "island_pbrt_sas_url" {
  description = "the storage account holding the queue"
}
