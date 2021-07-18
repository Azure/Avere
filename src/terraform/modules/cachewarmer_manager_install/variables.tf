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
  description = "the mount address that hosts the manager and worker bootstrap script"
}

variable "bootstrap_export_path" {
  description = "the export path that hosts the manager and worker bootstrap script"
}

variable "bootstrap_manager_script_path" {
  description = "the script path that hosts the manager bootstrap script"
}

variable "bootstrap_worker_script_path" {
  description = "the script path that hosts the worker bootstrap script"
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

variable "vmss_user_name" {
  description = "(optional) the username for the vmss vms"
  default     = "azureuser"
}

variable "vmss_password" {
  description = "(optional) the password for the vmss vms, this is unused if the public key is specified"
  default     = null
}

variable "vmss_ssh_public_key" {
  description = "(optional) the ssh public key for the vmss vms, this will be used by default, however if this is blank, the password will be used"
  default     = null
}

variable "vmss_subnet_name" {
  description = "(optional) the subnet to use for the VMSS, if not specified use the same subnet as the controller"
  default     = null
}
