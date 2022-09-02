variable "deploy_controller" {
  description = "specifies to create the controller or not"
  default     = true
}

variable "create_resource_group" {
  description = "specifies to create the resource group"
  default     = true
}

variable "resource_group_name" {
  description = "The resource group to contain the controller."
}

variable "location" {
  description = "The Azure Region into which the controller will be created."
}

variable "admin_username" {
  description = "Admin username on the controller."
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the controller.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "ssh_key_data" {
  description = "(optional) The public SSH key used for access to the controller.  If not specified, admin_password needs to be set.  The ssh_key_data takes precedence over the admin_password, and if set, the admin_password will be ignored."
}

variable "unique_name" {
  description = "The unique name used for the controller and for resource names associated with the VM."
  default     = "controller"
}

variable "vm_size" {
  description = "Size of the VM."
  default     = "Standard_A1_v2"
}

variable "user_assigned_managed_identity_id" {
  description = "Use this managed identity over system assigned identity."
  default     = null
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

variable "add_public_ip" {
  description = "specifies if the controller should have a publice ip"
  default     = false
}

variable "image_id" {
  description = "specifies a custom image id if not use marketplace"
  default     = null
}

variable "alternative_resource_groups" {
  description = "specifies alternative resource groups including those containing custom images or storage accounts"
  default     = []
}

variable "apply_patch" {
  description = "specifies if the controller should have a publice ip"
  default     = true
}

variable "ssh_port" {
  description = "specifies the tcp port to use for ssh"
  default     = 22
}

variable "static_ip_address" {
  description = "specifies the static ip address to use.  Leave null or blank to dynamically assign"
  default     = null
}

variable "tags" {
  description = "specifies key value pairs of tags"
  default     = {"azsecpack": "nonprod"}
}

variable "azsecpack_resource_group" {
  description = "specifies the name of the azsecpack resource group"
  default     = "AzSecPackAutoConfigRG"
}
