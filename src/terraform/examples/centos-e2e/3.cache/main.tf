/*
 * Deploys:
 * 1. (if specified) cache - HPC Cache or Avere vFXT
 * 2. (if specified) dns server - to spoof the addresses
 * 3. network security groups appropriate for each cache
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
  backend "azurerm" {
    key = "3.cache"
  }
}

provider "azurerm" {
  features {}
}

### Variables
variable "cache_rg" {
  type = string
}

variable "vm_admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "controller_private_ip" {
  type = string
}

variable "controller_add_public_ip" {
  type = bool
}

variable "install_cachewarmer" {
  type = bool
}

variable "cachewarmer_storage_account_name" {
  type = string
}

variable "queue_prefix_name" {
  type = string
}

variable "cache_type" {
  type = string
}
locals {
  hpccache        = "HPCCache"
  averevfxt       = "AverevFXT"
  deployAverevFXT = var.cache_type == local.averevfxt
  deployHPCCache  = var.cache_type == local.hpccache
}

variable "use_onprem_simulation" {
  type = bool
}

variable "real_nfsfiler_fqdn" {
  type = string
}

variable "real_nfs_targets" {
  type = list(
    object(
      { name      = string,
        addresses = list(string),
        junctions = set(
          object({
            namespace_path = string,
            nfs_export     = string,
            target_path    = string,
          })
        )
    })
  )
}

variable "hpc_cache_throughput" {
  type = string
}

variable "hpc_cache_size" {
  type = string
}

variable "hpc_cache_name" {
  type = string
}

variable "hpc_usage_model" {
  type = string
}

variable "vfxt_cluster_name" {
  type = string
}

variable "vfxt_sku" {
  type = string
}

variable "vfxt_ssh_key_data" {
  type = string
}

variable "vfxt_cache_policy" {
  type = string
}

variable "controller_image_id" {
  type = string
}

variable "vfxt_image_id" {
  type = string
}

variable "alternative_resource_groups" {
  type = list(string)
}

locals {
  nfs_targets = !var.use_onprem_simulation ? var.real_nfs_targets : [
    {
      name      = "nfsfiler",
      addresses = [data.terraform_remote_state.onprem.outputs.nfsfiler_fqdn],
      junctions = [
        {
          namespace_path = data.terraform_remote_state.onprem.outputs.nfsfiler_export,
          nfs_export     = data.terraform_remote_state.onprem.outputs.nfsfiler_export,
          target_path    = "",
        }
      ]
    }
  ]

  dns_servers = data.terraform_remote_state.network.outputs.onprem_dns_servers

  nfsfiler_fqdn = var.use_onprem_simulation ? data.terraform_remote_state.onprem.outputs.nfsfiler_fqdn : var.real_nfsfiler_fqdn

  proxy_uri = data.terraform_remote_state.network.outputs.use_proxy_server ? data.terraform_remote_state.network.outputs.proxy_uri : null
}

### Resources
data "azurerm_key_vault_secret" "virtualmachine" {
  name         = var.virtualmachine_key
  key_vault_id = var.key_vault_id
}

data "azurerm_key_vault_secret" "averecache" {
  name         = var.averecache_key
  key_vault_id = var.key_vault_id
}

# https://www.terraform.io/docs/language/settings/backends/azurerm.html#data-source-configuration
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    key                  = "1.network"
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
  }
}

data "terraform_remote_state" "onprem" {
  backend = "azurerm"
  config = {
    key                  = "onprem.tfstate"
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
  }
}

data "azurerm_subnet" "cache" {
  name                 = data.terraform_remote_state.network.outputs.cache_subnet_name
  virtual_network_name = data.terraform_remote_state.network.outputs.vnet_name
  resource_group_name  = data.terraform_remote_state.network.outputs.network_rg
}

resource "azurerm_resource_group" "cache_rg" {
  name     = var.cache_rg
  location = var.location
}

resource "azurerm_network_security_rule" "allowazureresourcemanager" {
  // remove the HPC Cache guard when HPC Cache supports proxy
  count                  = data.terraform_remote_state.network.outputs.use_proxy_server && !local.deployHPCCache ? 0 : 1
  name                   = "allowazureresourcemanager"
  priority               = 121
  direction              = "Outbound"
  access                 = "Allow"
  protocol               = "TCP"
  source_port_range      = "*"
  destination_port_range = "443"
  source_address_prefix  = "VirtualNetwork"
  // Azure Resource Manager
  destination_address_prefix  = "AzureResourceManager"
  resource_group_name         = data.terraform_remote_state.network.outputs.network_rg
  network_security_group_name = data.terraform_remote_state.network.outputs.cache_nsg_name
}

module "dnsserver" {
  source              = "github.com/Azure/Avere/src/terraform/modules/dnsserver"
  resource_group_name = var.cache_rg
  location            = var.location
  admin_username      = var.vm_admin_username
  admin_password      = data.azurerm_key_vault_secret.virtualmachine.value
  ssh_key_data        = var.ssh_public_key
  proxy               = local.proxy_uri

  // network details
  virtual_network_resource_group = data.terraform_remote_state.network.outputs.network_rg
  virtual_network_name           = data.terraform_remote_state.network.outputs.vnet_name
  virtual_network_subnet_name    = data.terraform_remote_state.network.outputs.cache_subnet_name

  // this is the address of the unbound dns server
  private_ip_address = data.terraform_remote_state.network.outputs.spoof_dns_server

  dns_server         = join(" ", local.dns_servers)
  avere_address_list = local.deployHPCCache ? azurerm_hpc_cache.hpc_cache[0].mount_addresses : avere_vfxt.vfxt[0].vserver_ip_addresses
  avere_filer_fqdn   = local.nfsfiler_fqdn

  // set the TTL
  dns_max_ttl_seconds = 300

  depends_on = [
    avere_vfxt.vfxt,
    azurerm_hpc_cache.hpc_cache,
  ]
}

////////////////////////////////////////////////////////////////
// HPC Cache related resources
////////////////////////////////////////////////////////////////
// HPC Cache requires this rule to establish communication to the cluster
resource "azurerm_network_security_rule" "allowazurecloud" {
  // remove the HPC Cache guard when HPC Cache supports proxy
  count                  = data.terraform_remote_state.network.outputs.use_proxy_server && !local.deployHPCCache ? 0 : 1
  name                   = "allowazurecloud"
  priority               = 150
  direction              = "Outbound"
  access                 = "Allow"
  protocol               = "TCP"
  source_port_range      = "*"
  destination_port_range = "443"
  source_address_prefix  = "VirtualNetwork"
  // Azure Resource Manager
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = data.terraform_remote_state.network.outputs.network_rg
  network_security_group_name = data.terraform_remote_state.network.outputs.cache_nsg_name
}

### Resources
resource "azurerm_hpc_cache" "hpc_cache" {
  count               = local.deployHPCCache ? 1 : 0
  name                = var.hpc_cache_name
  resource_group_name = azurerm_resource_group.cache_rg.name
  location            = azurerm_resource_group.cache_rg.location
  cache_size_in_gb    = var.hpc_cache_size
  subnet_id           = data.azurerm_subnet.cache.id
  sku_name            = var.hpc_cache_throughput

  depends_on = [
    azurerm_resource_group.cache_rg,
    resource.azurerm_network_security_rule.allowazureresourcemanager[0],
    resource.azurerm_network_security_rule.allowazureresourcemanager[0],
  ]
}

resource "azurerm_hpc_cache_nfs_target" "nfs_targets" {
  count               = local.deployHPCCache ? length(local.nfs_targets) : 0
  name                = local.nfs_targets[count.index]["name"]
  resource_group_name = azurerm_resource_group.cache_rg.name
  cache_name          = azurerm_hpc_cache.hpc_cache[0].name
  target_host_name    = local.nfs_targets[count.index]["addresses"][0]
  usage_model         = var.hpc_usage_model

  dynamic "namespace_junction" {
    for_each = local.nfs_targets[count.index]["junctions"]
    content {
      namespace_path = namespace_junction.value["namespace_path"]
      nfs_export     = namespace_junction.value["nfs_export"]
      target_path    = namespace_junction.value["target_path"]
    }
  }
}

////////////////////////////////////////////////////////////////
// Controller - used for cachewarmer and vFXT install
////////////////////////////////////////////////////////////////
resource "azurerm_network_security_rule" "controllersshin" {
  count                  = (local.deployAverevFXT || var.install_cachewarmer) && var.controller_add_public_ip ? 1 : 0
  name                   = "controllersshin"
  priority               = 120
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "Tcp"
  source_port_range      = "*"
  destination_port_range = data.terraform_remote_state.network.outputs.ssh_port
  source_address_prefix  = "*"
  //destination_address_prefix  = module.vfxtcontroller[0].controller_private_address
  destination_address_prefix  = "*"
  resource_group_name         = data.terraform_remote_state.network.outputs.network_rg
  network_security_group_name = data.terraform_remote_state.network.outputs.cache_nsg_name
}

module "vfxtcontroller" {
  count                       = local.deployAverevFXT || var.install_cachewarmer ? 1 : 0
  source                      = "github.com/Azure/Avere/src/terraform/modules/controller3"
  create_resource_group       = false
  resource_group_name         = var.cache_rg
  location                    = var.location
  admin_username              = var.vm_admin_username
  admin_password              = data.azurerm_key_vault_secret.virtualmachine.value
  ssh_key_data                = var.ssh_public_key
  add_public_ip               = var.controller_add_public_ip
  image_id                    = var.controller_image_id
  alternative_resource_groups = var.alternative_resource_groups
  ssh_port                    = data.terraform_remote_state.network.outputs.ssh_port
  static_ip_address           = var.controller_private_ip

  // network details
  virtual_network_resource_group = data.terraform_remote_state.network.outputs.network_rg
  virtual_network_name           = data.terraform_remote_state.network.outputs.vnet_name
  virtual_network_subnet_name    = data.terraform_remote_state.network.outputs.cache_subnet_name

  depends_on = [
    azurerm_resource_group.cache_rg,
    azurerm_network_security_rule.controllersshin[0],
  ]
}

////////////////////////////////////////////////////////////////
// Avere vFXT related resources
////////////////////////////////////////////////////////////////
resource "azurerm_network_security_rule" "avere" {
  count                  = local.deployAverevFXT && !data.terraform_remote_state.network.outputs.use_proxy_server ? 1 : 0
  name                   = "avere"
  priority               = 120
  direction              = "Outbound"
  access                 = "Allow"
  protocol               = "TCP"
  source_port_range      = "*"
  destination_port_range = "443"
  source_address_prefix  = "VirtualNetwork"
  // download.averesystems.com resolves to 104.45.184.87
  destination_address_prefix  = "104.45.184.87"
  resource_group_name         = data.terraform_remote_state.network.outputs.network_rg
  network_security_group_name = data.terraform_remote_state.network.outputs.cache_nsg_name
}

resource "avere_vfxt" "vfxt" {
  count                     = local.deployAverevFXT ? 1 : 0
  controller_address        = module.vfxtcontroller[0].controller_address
  controller_admin_username = module.vfxtcontroller[0].controller_username
  // ssh key takes precedence over controller password
  controller_admin_password = var.ssh_public_key != null && var.ssh_public_key != "" ? "" : data.azurerm_key_vault_secret.virtualmachine.value
  controller_ssh_port       = data.terraform_remote_state.network.outputs.ssh_port
  node_size                 = var.vfxt_sku

  dns_server = join(" ", local.dns_servers)
  dns_search = data.terraform_remote_state.network.outputs.dns_search_domain == "" ? null : data.terraform_remote_state.network.outputs.dns_search_domain

  proxy_uri         = local.proxy_uri
  cluster_proxy_uri = local.proxy_uri
  image_id          = var.vfxt_image_id

  location                     = var.location
  azure_resource_group         = var.cache_rg
  azure_network_resource_group = data.terraform_remote_state.network.outputs.network_rg
  azure_network_name           = data.terraform_remote_state.network.outputs.vnet_name
  azure_subnet_name            = data.terraform_remote_state.network.outputs.cache_subnet_name
  vfxt_cluster_name            = var.vfxt_cluster_name
  vfxt_admin_password          = data.azurerm_key_vault_secret.averecache.value
  vfxt_ssh_key_data            = var.vfxt_ssh_key_data == "" ? null : var.vfxt_ssh_key_data
  vfxt_node_count              = 3

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller[0],
    resource.azurerm_network_security_rule.avere[0],
    resource.azurerm_network_security_rule.allowazureresourcemanager[0],
  ]

  dynamic "core_filer" {
    for_each = local.nfs_targets
    content {
      name               = core_filer.value["name"]
      fqdn_or_primary_ip = join(" ", core_filer.value["addresses"])
      cache_policy       = var.vfxt_cache_policy

      dynamic "junction" {
        for_each = core_filer.value["junctions"]
        content {
          namespace_path      = junction.value["namespace_path"]
          core_filer_export   = junction.value["nfs_export"]
          export_subdirectory = junction.value["target_path"]
        }
      }
    }
  }
}

////////////////////////////////////////////////////////////////
// Cachewarmer
////////////////////////////////////////////////////////////////
resource "azurerm_storage_account" "storage" {
  count                    = var.install_cachewarmer ? 1 : 0
  name                     = var.cachewarmer_storage_account_name
  resource_group_name      = var.cache_rg // must be in same rg as controller for access by controller
  location                 = var.location
  account_kind             = "Storage" // set to storage v1 for cheapest cost on queue transactions
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [
    azurerm_resource_group.cache_rg,
  ]
}

module "cachewarmer_prepare_bootstrapdir" {
  count  = var.install_cachewarmer ? 1 : 0
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_prepare_bootstrapdir"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller[0].controller_address
  jumpbox_username     = module.vfxtcontroller[0].controller_username
  jumpbox_password     = data.azurerm_key_vault_secret.virtualmachine.value
  jumpbox_ssh_key_data = var.ssh_public_key
  proxy                = local.proxy_uri

  // bootstrap directory to store the cache manager binaries and install scripts
  bootstrap_mount_address = data.terraform_remote_state.onprem.outputs.nfsfiler_address
  bootstrap_export_path   = data.terraform_remote_state.onprem.outputs.nfsfiler_export
  bootstrap_subdir        = "/tools/bootstrap"

  # use the release binaries by setting build_cachewarmer to false
  build_cachewarmer = false

  depends_on = [
    module.vfxtcontroller,
  ]
}

module "cachewarmer_manager_install" {
  count  = var.install_cachewarmer ? 1 : 0
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_manager_install"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller[0].controller_address
  jumpbox_username     = module.vfxtcontroller[0].controller_username
  jumpbox_password     = data.azurerm_key_vault_secret.virtualmachine.value
  jumpbox_ssh_key_data = var.ssh_public_key
  proxy                = local.proxy_uri

  // bootstrap directory to install the cache manager service
  bootstrap_mount_address       = module.cachewarmer_prepare_bootstrapdir[0].bootstrap_mount_address
  bootstrap_export_path         = module.cachewarmer_prepare_bootstrapdir[0].bootstrap_export_path
  bootstrap_manager_script_path = module.cachewarmer_prepare_bootstrapdir[0].cachewarmer_manager_bootstrap_script_path

  // the job path
  storage_account    = azurerm_storage_account.storage[0].name
  storage_account_rg = azurerm_storage_account.storage[0].resource_group_name
  queue_name_prefix  = var.queue_prefix_name

  // the cachewarmer VMSS auth details
  vmss_user_name      = module.vfxtcontroller[0].controller_username
  vmss_password       = data.azurerm_key_vault_secret.virtualmachine.value
  vmss_ssh_public_key = var.ssh_public_key
  vmss_subnet_name    = data.terraform_remote_state.network.outputs.render_subnet_name
  vmss_worker_count   = length(local.deployAverevFXT ? avere_vfxt.vfxt[0].node_names : azurerm_hpc_cache.hpc_cache[0].mount_addresses) * 4 // 4 D2sv3 nodes per cache node

  // the cachewarmer install the work script
  bootstrap_worker_script_path = module.cachewarmer_prepare_bootstrapdir[0].cachewarmer_worker_bootstrap_script_path

  depends_on = [
    module.cachewarmer_prepare_bootstrapdir,
    avere_vfxt.vfxt,
    azurerm_hpc_cache.hpc_cache,
    azurerm_storage_account.storage,
  ]
}

module "cachewarmer_worker_install" {
  count  = var.install_cachewarmer ? 1 : 0
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_worker_install"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller[0].controller_address
  jumpbox_username     = module.vfxtcontroller[0].controller_username
  jumpbox_password     = data.azurerm_key_vault_secret.virtualmachine.value
  jumpbox_ssh_key_data = var.ssh_public_key
  proxy                = local.proxy_uri

  // bootstrap directory to install the cache manager service
  bootstrap_mount_address      = module.cachewarmer_prepare_bootstrapdir[0].bootstrap_mount_address
  bootstrap_export_path        = module.cachewarmer_prepare_bootstrapdir[0].bootstrap_export_path
  bootstrap_worker_script_path = module.cachewarmer_prepare_bootstrapdir[0].cachewarmer_worker_bootstrap_script_path

  // the job path
  storage_account    = azurerm_storage_account.storage[0].name
  storage_account_rg = azurerm_storage_account.storage[0].resource_group_name
  queue_name_prefix  = var.queue_prefix_name

  depends_on = [
    module.cachewarmer_manager_install,
  ]
}

module "cachewarmer_submitjobs" {
  count  = var.install_cachewarmer ? 1 : 0
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_submitjobs"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller[0].controller_address
  jumpbox_username     = module.vfxtcontroller[0].controller_username
  jumpbox_password     = data.azurerm_key_vault_secret.virtualmachine.value
  jumpbox_ssh_key_data = var.ssh_public_key
  proxy                = local.proxy_uri

  // the job path
  storage_account    = azurerm_storage_account.storage[0].name
  storage_account_rg = azurerm_storage_account.storage[0].resource_group_name
  queue_name_prefix  = var.queue_prefix_name

  // the path to warm
  warm_mount_addresses = join(",", tolist(local.deployAverevFXT ? avere_vfxt.vfxt[0].vserver_ip_addresses : azurerm_hpc_cache.hpc_cache[0].mount_addresses))
  warm_paths = {
    "${data.terraform_remote_state.onprem.outputs.nfsfiler_export}" : ["/tools", "/island"],
  }

  inclusion_csv    = "" // example "*.jpg,*.png"
  exclusion_csv    = "" // example "*.tgz,*.tmp"
  maxFileSizeBytes = 0

  block_until_warm = true

  depends_on = [
    module.cachewarmer_worker_install,
    avere_vfxt.vfxt,
    azurerm_hpc_cache.hpc_cache,
    azurerm_storage_account.storage,
  ]
}

### Outputs
output "controller_username" {
  value = length(module.vfxtcontroller) == 0 ? "" : module.vfxtcontroller[0].controller_username
}

output "controller_address" {
  value = length(module.vfxtcontroller) == 0 ? "" : module.vfxtcontroller[0].controller_address
}

output "mount_addresses" {
  value = local.deployHPCCache ? tolist(azurerm_hpc_cache.hpc_cache[0].mount_addresses) : tolist(avere_vfxt.vfxt[0].vserver_ip_addresses)
}

output "management_ip" {
  value = local.deployAverevFXT ? avere_vfxt.vfxt[0].vfxt_management_ip : ""
}
