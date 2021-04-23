variable "create_resource_group" {
  description = "specifies to create the resource group"
  default     = true
}

variable "resource_group_name" {
  description = "The resource group to contain the NFS filer."
}

variable "location" {
  description = "The Azure Region into which all resources of NFS filer will be created."
}

variable "vnet_address_space" {
  description = "The full address space of the virtual network"
  default     = "10.0.0.0/16"
}

variable "subnet_cloud_cache_subnet_name" {
  description = "The name for the cloud cache subnet."
  default     = "cloud_cache"
}

variable "subnet_cloud_cache_address_prefix" {
  description = "The address prefix used for the cloud cache subnet."
  default     = "10.0.1.0/24"
}

variable "subnet_cloud_filers_subnet_name" {
  description = "The name for the cloud filers subnet."
  default     = "cloud_filers"
}

variable "subnet_cloud_filers_address_prefix" {
  description = "The address prefix used for the cloud filers subnet."
  default     = "10.0.2.0/25"
}

variable "subnet_cloud_filers_ha_subnet_name" {
  description = "The name for the cloud filers subnet."
  default     = "cloud_filers_ha"
}

variable "subnet_cloud_filers_ha_address_prefix" {
  description = "The address prefix used for the cloud filers ha subnet."
  default     = "10.0.2.128/25"
}


variable "subnet_jumpbox_subnet_name" {
  description = "The name for the jumpbox subnet."
  default     = "jumpbox"
}

variable "subnet_jumpbox_address_prefix" {
  description = "The address prefix used for the jumpbox subnet."
  default     = "10.0.3.0/24"
}

variable "subnet_render_clients1_subnet_name" {
  description = "The name for the first render clients subnet."
  default     = "render_clients1"
}

variable "subnet_render_clients1_address_prefix" {
  description = "The address prefix used for the first render clients subnet."
  default     = "10.0.4.0/23"
}

variable "subnet_render_clients2_subnet_name" {
  description = "The name for the second render clients subnet."
  default     = "render_clients2"
}

variable "subnet_render_clients2_address_prefix" {
  description = "The address prefix used for the second render clients subnet."
  default     = "10.0.6.0/23"
}

variable "dns_servers" {
  description = "a list of dns servers"
  default     = null
}

variable "module_depends_on" {
  default     = [""]
  description = "depends on workaround discussed in https://discuss.hashicorp.com/t/tips-howto-implement-module-depends-on-emulation/2305/2"
}

variable "open_external_ports" {
  default = [22, 3389]
  # ports 443, 4172, 60443 required for terradici
  # default = [22,3389,443,4172,60443]
  description = "these are the tcp ports to open externally on the jumpbox subnet"
}

variable "open_external_udp_ports" {
  default = []
  # ports 4172 required for terradici
  # default = [4172]
  description = "these are the udp ports to open externally on the jumpbox subnet"
}

variable "open_external_sources" {
  default     = ["*"]
  description = "this is the external source to open on the subnet"
}
