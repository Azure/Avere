variable "resource_group_name" {
    description = "The resource group to contain the NFS filer."
}

variable "location" {
    description = "The Azure Region into which all resources of NFS filer will be created."
}

variable "vnet_address_space" {
    description = "The full address space of the virtual network"
    default = "10.0.0.0/16"
}

variable "subnet_cloud_cache_subnet_name" {
    description = "The name for the cloud cache subnet."
    default = "cloud_cache"
}

variable "subnet_cloud_cache_address_prefix" {
    description = "The address prefix used for the cloud cache subnet."
    default = "10.0.1.0/24"
}

variable "subnet_cloud_filers_subnet_name" {
    description = "The name for the cloud filers subnet."
    default = "cloud_filers"
}

variable "subnet_cloud_filers_address_prefix" {
    description = "The address prefix used for the cloud filers subnet."
    default = "10.0.2.0/24"
}

variable "subnet_jumpbox_subnet_name" {
    description = "The name for the jumpbox subnet."
    default = "jumpbox"
}

variable "subnet_jumpbox_address_prefix" {
    description = "The address prefix used for the jumpbox subnet."
    default = "10.0.3.0/24"
}

variable "subnet_render_clients1_subnet_name" {
    description = "The name for the first render clients subnet."
   default = "render_clients1"
}

variable "subnet_render_clients1_address_prefix" {
    description = "The address prefix used for the first render clients subnet."
    default = "10.0.4.0/23"
}

variable "subnet_render_clients2_subnet_name" {
    description = "The name for the second render clients subnet."
    default = "render_clients2"
}

variable "subnet_render_clients2_address_prefix" {
    description = "The address prefix used for the second render clients subnet."
    default = "10.0.6.0/23"
}

variable "subnet_proxy_subnet_name" {
    description = "The name for the proxy subnet."
    default = "proxy"
}

variable "subnet_proxy_address_prefix" {
    description = "The address prefix used for the proxy subnet."
    default = "10.0.255.248/29"
}

variable "ssh_source_address_prefix" {
    description = "The source address prefix granted for ssh access."
    default = "*"
}

variable "open_external_ports" {
    default = [22]
    description = "these are the ports to open externally on the jumpbox subnet, default is 22"
}

variable "open_external_sources" {
    default = ["*"]
    description = "this is the external source to open on the subnet"
}