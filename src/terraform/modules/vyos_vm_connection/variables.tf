variable "vyos_vm_id" {
  description = "the Azure Resource ID of the VyOS vm."
}

variable "vpn_preshared_key" {
  description = "The private key used for the vpn tunnel."
  type        = string
  sensitive   = true
}

variable "vyos_vti_dummy_address" {
  description = "A dummy address on the same subnet for the VTI interface"
  type        = string
}

variable "vyos_public_ip" {
  description = "The public ip of the VyOS server"
  type        = string
}

variable "vyos_bgp_address" {
  description = "The bgp ip address"
  type        = string
}

variable "vyos_asn" {
  description = "The ASN of the VyOS VM."
  type        = number
}

variable "azure_vpn_gateway_public_ip" {
  description = "The public ip address of the Azure VPN Gateway."
  type        = string
}

variable "azure_vpn_gateway_bgp_address" {
  description = "The bgp address of the Azure VPN Gateway."
}

variable "azure_vpn_gateway_asn" {
  description = "The ASN of the Azure VPN Gateway."
  type        = number
}
