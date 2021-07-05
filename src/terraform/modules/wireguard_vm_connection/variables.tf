variable "wireguard_vm_id" {
  description = "the Azure Resource ID of the wireguard vm."
}

variable "wireguard_private_key" {
  description = "The private key used for the wireguard tunnel. Generate from https://www.wireguardconfig.com/ or for more security install ubuntu + wireguard, and generate per https://www.wireguard.com/quickstart/."
  type        = string
  sensitive   = true
}

variable "wireguard_peer_public_key" {
  description = "The public key of the wireguard peer.  Generate from https://www.wireguardconfig.com/ or for more security install ubuntu + wireguard, and generate per https://www.wireguard.com/quickstart/"
  type        = string
}

variable "peer_public_address" {
  description = "The peer public address"
  type        = string
}

variable "peer_address_space" {
  description = "The peer address space"
  type        = list(string)
}

variable "is_primary" {
  description = "A tunnel has a primary and secondary side.  This is needed for wg interface configuration to know the correct sde of tunnel."
  type        = bool
}

variable "dummy_ip_prefix" {
  description = "The first 3 octets of a private dummy ip range, not overlapping with any other ranges."

}

variable "tunnel_count" {
  description = "To increase throughput, specify the number of tunnels to create between wireguard peers.  This will use ECMP to balance across the tunnels where each source/dest pair will have maximum bandwidth of a single tunnel due to source/dest pair hashing."
  type        = number
}

variable "base_udp_port" {
  description = "The udp port for the first tunnel.  Each additional tunnel has a monotonically increasing udp port from the base udp port."
  type        = number
}
