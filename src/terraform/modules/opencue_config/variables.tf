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

variable "nfs_address" {
  description = "the private name or ip address of the nfs server"
}

variable "nfs_export_path" {
  description = "The writeable path exported on the nfs server that will host the boostrap scripts"
}

variable "ssh_port" {
  description = "specifies the tcp port to use for ssh"
  default     = 22
}
