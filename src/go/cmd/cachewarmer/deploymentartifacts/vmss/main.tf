// customize the VMSS by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // network details
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "rendervnet"
    virtual_network_subnet_name = "render_clients1"
    
    // nfs job folder details
    bootstrap_address = "10.0.1.11"
    bootstrap_export_path = ""
    storage_account = ""
    storage_key = ""
    queue_prefix = "isilon1"
    
    // vmss details
    vmss_resource_group_name = "vmss_rg"
    unique_name = "unique"
    vm_count = 3
    vmss_size = "Standard_D2s_v3"
    use_ephemeral_os_disk = true
}

provider "azurerm" {
    version = "~>2.4.0"
    features {}
}

resource "azurerm_resource_group" "vmss" {
  name     = local.vmss_resource_group_name
  location = local.location
}

data "azurerm_subnet" "vnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resource_group
}

locals {
    // non-configurable bootstrap details
    bootstrap_path = "/b"
    cachewarmer_worker_bootstrap_script_path = "/bootstrap/bootstrap.cachewarmer-worker.sh"
    env_vars = " BOOTSTRAP_PATH=\"${local.bootstrap_path}\" BOOTSTRAP_SCRIPT=\"${local.cachewarmer_worker_bootstrap_script_path}\" STORAGE_ACCOUNT=\"${local.storage_account}\" STORAGE_KEY=\"${local.storage_key}\" QUEUE_PREFIX=\"${local.queue_prefix}\" "
    cloud_init_file = templatefile("cloud-init.tpl", { bootstrap_address = local.boostrap_address, export_path = local.bootstrap_export_path, bootstrap_path = local.bootstrap_path, bootstrap_script_path = local.cachewarmer_worker_bootstrap_script_path, env_vars=local.env_vars})
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = local.unique_name
  resource_group_name = azurerm_resource_group.vmss.name
  location            = azurerm_resource_group.vmss.location
  sku                 = local.vmss_size
  instances           = local.vm_count
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? local.vm_admin_password : null
  priority            = "Spot"
  eviction_policy     = "Delete"
  overprovision       = false
  custom_data         = base64encode(local.cloud_init_file)

  dynamic "admin_ssh_key" {
      for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
      content {
          username   = local.vm_admin_username
          public_key = local.vm_ssh_key_data
      }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadOnly"

    dynamic "diff_disk_settings" {
      for_each = local.use_ephemeral_os_disk == true ? [local.use_ephemeral_os_disk] : []
      content {
          option = "Local"
      }
    }
  }

  network_interface {
    name    = "vminic-${local.unique_name}"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = data.azurerm_subnet.vnet.id
    }
  }
}

output "vmss_id" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.id
}

output "vmss_resource_group" {
  value = azurerm_resource_group.vmss.name
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.name
}

output "vmss_addresses_command" {
    // local-exec doesn't return output, and the only way to 
    // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
    // in the meantime just provide the az cli command to
    // the customer
    value = "az vmss nic list -g ${azurerm_resource_group.vmss.name} --vmss-name ${azurerm_linux_virtual_machine_scale_set.vmss.name} --query \"[].ipConfigurations[].privateIpAddress\""
}