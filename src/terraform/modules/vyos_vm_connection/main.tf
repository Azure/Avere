locals {
  env_vars = " ONPREM_VTI_DUMMY_ADDRESS=${var.vyos_vti_dummy_address} VYOS_ADDRESS=${var.vyos_public_ip} VYOS_BGP_ADDRESS=${var.vyos_bgp_address} CLOUD_ADDRESS=${var.azure_vpn_gateway_public_ip} CLOUD_BGP_ADDRESS=${var.azure_vpn_gateway_bgp_address} PRE_SHARED_KEY=${var.vpn_preshared_key} VYOS_ASN=${var.vyos_asn} CLOUD_ASN=${var.azure_vpn_gateway_asn} "
}

resource "azurerm_virtual_machine_extension" "vyosvmcse" {
  name                 = "vyosvmcse"
  virtual_machine_id   = var.vyos_vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  // protected_settings necessary to pass the private key
  protected_settings = <<SETTINGS
    {
        "commandToExecute": " ${local.env_vars} sg vyattacfg -c /opt/install.sh"
    }
SETTINGS
}
