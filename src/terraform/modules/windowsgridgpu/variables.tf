variable "resource_group_name" {
  description = "The existing resource group to contain the dnsserver."
}

variable "location" {
  description = "The Azure Region into which the dnsserver will be created."
}

variable "admin_username" {
  description = "Admin username on the dnsserver."
  default     = "azureuser"
}

variable "admin_password" {
  description = "(optional) The password used for access to the dnsserver.  If not specified, ssh_key_data needs to be set."
  default     = null
}

variable "unique_name" {
  description = "The unique name used for the dnsserver and for resource names associated with the VM."
  default     = "wingrid"
}

variable "vm_size" {
  description = "Size of the VM."
  default     = "Standard_NV6"
}

variable "ad_domain" {
  description = "Size of the VM."
  default     = ""
}

variable "ou_path" {
  description = "Size of the VM."
  default     = ""
}

variable "ad_username" {
  description = "Size of the VM."
  default     = ""
}

variable "ad_password" {
  description = "Size of the VM."
  default     = ""
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

variable "private_ip_address" {
  description = "specifies a static private ip address to use"
  default     = null
}

variable "image_id" {
  description = "specifies a custom image id, if not use marketplace"
  default     = null
}

variable "install_pcoip" {
  description = "specifies true or false to install pcoip"
  default     = true
}

variable "grid_url" {
  description = "specifies the grid url"
  default     = "https:/URI_TO_AZURE_STORAGE_ACCOUNT/bin/Graphics/Windows/461.09_grid_win10_server2016_server2019_64bit_azure_swl.exe?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
}

variable "teradici_pcoipagent_url" {
  description = "specifies the teradici pcoipagent"
  default     = "https://URI_TO_AZURE_STORAGE_ACCOUNT/bin/Teradici/pcoip-agent-graphics_21.03.0.exe?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
}

variable "teradici_license_key" {
  description = "specifies the teradici pcoipagent license key"
  default     = ""
}

variable "license_type" {
  description = "specify 'Windows_Client' to specifies the type of on-premise license (also known as Azure Hybrid Use Benefit https://azure.microsoft.com/en-us/pricing/hybrid-benefit/faq/) which should be used for this Virtual Machine."
  default     = "None"
}

variable "storage_account_type" {
  description = "specify the type of OS Disk.  Possible values are Standard_LRS, StandardSSD_LRS and Premium_LRS"
  default     = "StandardSSD_LRS"
}
