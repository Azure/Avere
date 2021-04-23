
locals {
  script_file_b64 = base64gzip(replace(file("${path.module}/configure-anvil.py"), "\r", ""))

  command = "mkdir -p /opt && touch /opt/configure-anvil.py && echo ${local.script_file_b64} | base64 -d | gunzip > /opt/configure-anvil.py && python2 /opt/configure-anvil.py ${var.anvil_data_cluster_ip} ${var.web_ui_password} ${var.dsx_count}  -a '${var.ad_domain}' -u '${var.ad_user}' -p '${var.ad_user_password}' -n '${var.local_site_name}' -s '${var.nfs_export_path}' --azure-account '${var.azure_storage_account}' --azure-account-key '${var.azure_storage_account_key}' --azure-account-container '${var.azure_storage_account_container}' "
}

resource "azurerm_virtual_machine_extension" "cse" {
  name                 = "${var.anvil_hostname}-cse"
  virtual_machine_id   = var.anvil_arm_virtual_machine_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  // sleep 30 to ensure the disk has attached, and restart the pd service
  // sleep 30 && systemctl restart pd-first-boot
  settings = <<SETTINGS
    {
        "commandToExecute": "${local.command}"
    }
SETTINGS
}
