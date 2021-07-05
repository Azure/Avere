locals {
  tunnel_side            = var.is_primary ? "primary" : "secondary"
  peer_address_space_csv = join(",", var.peer_address_space)

  env_vars = " PRIVATE_KEY='${var.wireguard_private_key}' PEER_PUBLIC_KEY='${var.wireguard_peer_public_key}' PEER_PUBLIC_ADDRESS='${var.peer_public_address}' PEER_ADDRESS_SPACE_CSV='${local.peer_address_space_csv}' TUNNEL_SIDE='${local.tunnel_side}' DUMMY_IP_PREFIX='${var.dummy_ip_prefix}' TUNNEL_COUNT=${var.tunnel_count} BASE_UDP_PORT=${var.base_udp_port} "
}

resource "azurerm_virtual_machine_extension" "wireguard_vm_id" {
  name                 = "cloudwireguardcse"
  virtual_machine_id   = var.wireguard_vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  // protected_settings necessary to pass the private key
  //  protected_settings = <<SETTINGS
  settings = <<SETTINGS
    {
        "commandToExecute": " ${local.env_vars} /bin/bash /opt/install.sh"
    }
SETTINGS
}
