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

variable "storage_account_rg" {
  description = "the storage account resource group"
}

variable "storage_account" {
  description = "the storage account holding the queue"
}

variable "queue_name_prefix" {
  description = "the queue name prefix for the job management"
}

variable "warm_mount_addresses" {
  description = "the warm target cache filer mount addresses separated by comma"
}

variable "warm_paths" {
  description = "the export and target paths to warm, separated by ':'"
  default     = {}
}

variable "inclusion_csv" {
  description = "the inclusion list of file match strings per https://golang.org/pkg/path/filepath/#Match.  Leave blank to include everything."
}

variable "exclusion_csv" {
  description = "the exclusion list of file match strings per https://golang.org/pkg/path/filepath/#Match.  Leave blank to not exlude anything."
}

variable "maxFileSizeBytes" {
  description = "the maximum file size in bytes to warm."
  type        = number
  default     = 0
}

variable "block_until_warm" {
  description = "block the operation until the cache warming has finished"
  default     = true
}
