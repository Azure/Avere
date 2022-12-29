terraform {
  required_version = ">= 1.3.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.37.0"
    }
  }
  backend "azurerm" {
    key = "1.network"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "global" {
  source = "../0.global/module"
}

variable "resourceGroupName" {
  type = string
}

variable "computeNetwork" {
  type = object(
    {
      name           = string
      regionName     = string
      addressSpace   = list(string)
      dnsIpAddresses = list(string)
      subnets = list(object(
        {
          name              = string
          addressSpace      = list(string)
          serviceEndpoints  = list(string)
          serviceDelegation = string
        }
      ))
      subnetIndex = object(
        {
          farm        = number
          workstation = number
          storage     = number
          cache       = number
        }
      )
    }
  )
}

variable "storageNetwork" {
  type = object(
    {
      name           = string
      regionName     = string
      addressSpace   = list(string)
      dnsIpAddresses = list(string)
      subnets = list(object(
        {
          name              = string
          addressSpace      = list(string)
          serviceEndpoints  = list(string)
          serviceDelegation = string
        }
      ))
      subnetIndex = object(
        {
          primary     = number
          secondary   = number
          netAppFiles = number
        }
      )
    }
  )
}

variable "networkPeering" {
  type = object(
    {
      enable                      = bool
      allowRemoteNetworkAccess    = bool
      allowRemoteForwardedTraffic = bool
    }
  )
}

variable "privateDns" {
  type = object(
    {
      zoneName               = string
      enableAutoRegistration = bool
    }
  )
}

variable "bastion" {
  type = object(
    {
      enable              = bool
      sku                 = string
      scaleUnitCount      = number
      enableFileCopy      = bool
      enableCopyPaste     = bool
      enableIpConnect     = bool
      enableTunneling     = bool
      enableShareableLink = bool
    }
  )
}

variable "natGateway" {
  type = object(
    {
      enable = bool
    }
  )
}

variable "networkGateway" {
  type = object(
    {
      type = string
    }
  )
}

variable "vpnGateway" {
  type = object(
    {
      sku                = string
      type               = string
      generation         = string
      enableBgp          = bool
      enableActiveActive = bool
      pointToSiteClient = object(
        {
          addressSpace    = list(string)
          certificateName = string
          certificateData = string
        }
      )
    }
  )
}

variable "vpnGatewayLocal" {
  type = object(
    {
      fqdn         = string
      address      = string
      addressSpace = list(string)
      bgp = object(
        {
          enable         = bool
          asn            = number
          peerWeight     = number
          peeringAddress = string
        }
      )
    }
  )
}

variable "expressRouteGateway" {
  type = object(
    {
      sku = string
      connection = object(
        {
          circuitId        = string
          authorizationKey = string
          enableFastPath   = bool
        }
      )
    }
  )
}

variable "monitor" {
  type = object(
    {
      enablePrivateLink = bool
    }
  )
}

data "azurerm_key_vault" "render" {
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "gateway_connection" {
  name         = module.global.keyVault.secretName.gatewayConnection
  key_vault_id = data.azurerm_key_vault.render.id
}

data "azurerm_storage_account" "render" {
  name                = module.global.rootStorage.accountName
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_log_analytics_workspace" "render" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = module.global.monitorWorkspace.name
  resource_group_name = module.global.resourceGroupName
}

locals {
  computeNetwork = var.computeNetwork.regionName != "" ? var.computeNetwork : merge(var.computeNetwork,
    { regionName = module.global.regionName }
  )
  storageNetwork = var.storageNetwork.regionName != "" ? var.storageNetwork : merge(var.storageNetwork,
    { regionName = module.global.regionName }
  )
  computeNetworkSubnets = [
    for virtualNetworkSubnet in local.computeNetwork.subnets : merge(virtualNetworkSubnet,
      { virtualNetworkName = local.computeNetwork.name }
    ) if virtualNetworkSubnet.name != "GatewaySubnet"
  ]
  storageNetworkSubnets = [
    for virtualNetworkSubnet in local.storageNetwork.subnets : merge(virtualNetworkSubnet,
      { virtualNetworkName = local.storageNetwork.name }
    ) if virtualNetworkSubnet.name != "GatewaySubnet" && local.storageNetwork.name != ""
  ]
  computeStorageSubnet = merge(local.computeNetwork.subnets[local.computeNetwork.subnetIndex.storage],
    { virtualNetworkName = local.computeNetwork.name }
  )
  storageSubnets  = setunion(local.storageNetworkSubnets, [local.computeStorageSubnet])
  virtualNetworks = distinct(local.storageNetwork.name == "" ? [local.computeNetwork, local.computeNetwork] : [local.computeNetwork, local.storageNetwork])
  virtualNetworksSubnets = flatten([
    for virtualNetwork in local.virtualNetworks : [
      for virtualNetworkSubnet in virtualNetwork.subnets : merge(virtualNetworkSubnet,
        { virtualNetworkName = virtualNetwork.name },
        { regionName         = virtualNetwork.regionName }
      )
    ]
  ])
  virtualNetworksSubnetsSecurity = [
    for virtualNetworksSubnet in local.virtualNetworksSubnets : virtualNetworksSubnet if virtualNetworksSubnet.name != "GatewaySubnet" && virtualNetworksSubnet.name != "AzureBastionSubnet" && virtualNetworksSubnet.serviceDelegation == ""
  ]
  virtualGatewayNetworks = flatten([
    for virtualNetwork in local.virtualNetworks : [
      for virtualNetworkSubnet in virtualNetwork.subnets : virtualNetwork if virtualNetworkSubnet.name == "GatewaySubnet"
    ]
  ])
  virtualGatewayNetworkNames = [
    for virtualGatewayNetwork in local.virtualGatewayNetworks : virtualGatewayNetwork.name
  ]
  virtualGatewayActiveActive = var.networkGateway.type == "Vpn" && var.vpnGateway.enableActiveActive
}

resource "azurerm_resource_group" "network" {
  name     = var.resourceGroupName
  location = local.computeNetwork.regionName
}

#################################################################################################
# Virtual Network (https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) #
#################################################################################################

resource "azurerm_virtual_network" "network" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  address_space       = each.value.addressSpace
  dns_servers         = each.value.dnsIpAddresses
}

resource "azurerm_subnet" "network" {
  for_each = {
    for virtualNetworksSubnet in local.virtualNetworksSubnets : "${virtualNetworksSubnet.virtualNetworkName}.${virtualNetworksSubnet.name}" => virtualNetworksSubnet
  }
  name                                          = each.value.name
  resource_group_name                           = azurerm_resource_group.network.name
  virtual_network_name                          = each.value.virtualNetworkName
  address_prefixes                              = each.value.addressSpace
  service_endpoints                             = each.value.serviceEndpoints
  private_endpoint_network_policies_enabled     = each.value.name == "GatewaySubnet"
  private_link_service_network_policies_enabled = each.value.name == "GatewaySubnet"
  dynamic delegation {
    for_each = each.value.serviceDelegation != "" ? [1] : []
    content {
      name = "delegation"
      service_delegation {
        name = each.value.serviceDelegation
      }
    }
  }
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_network_security_group" "network" {
  for_each = {
    for virtualNetworksSubnet in local.virtualNetworksSubnetsSecurity : "${virtualNetworksSubnet.virtualNetworkName}.${virtualNetworksSubnet.name}" => virtualNetworksSubnet
  }
  name                = "${each.value.virtualNetworkName}.${each.value.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  security_rule {
    name                       = "AllowOutARM"
    priority                   = 3000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "AzureResourceManager"
    destination_port_range     = "*"
  }
  security_rule {
    name                       = "AllowOutStorage"
    priority                   = 3100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "Storage"
    destination_port_range     = "*"
  }
  security_rule {
    name                       = "DenyOutInternet"
    priority                   = 4000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "Internet"
    destination_port_range     = "*"
  }
  dynamic security_rule {
    for_each = each.value.name == "Farm" ? [1] : []
    content {
      name                       = "AllowOutHTTPS"
      priority                   = 3200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "443"
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowInPCoIP[TCP]"
      priority                   = 2000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_ranges = [
        "443",
        "4172",
        "60433"
      ]
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowInPCoIP[UDP]"
      priority                   = 2100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "4172"
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowOutHTTP"
      priority                   = 2000
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "80"
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowOutPCoIP[TCP]"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "443"
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowOutPCoIP[UDP]"
      priority                   = 2200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "4172"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "network" {
  for_each = {
    for virtualNetworksSubnet in local.virtualNetworksSubnetsSecurity : "${virtualNetworksSubnet.virtualNetworkName}.${virtualNetworksSubnet.name}" => virtualNetworksSubnet
  }
  subnet_id                 = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
  network_security_group_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/networkSecurityGroups/${each.value.virtualNetworkName}.${each.value.name}"
  depends_on = [
    azurerm_subnet.network,
    azurerm_network_security_group.network
  ]
}

################################################################################################################
# Virtual Network Peering (https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview) #
################################################################################################################

resource "azurerm_virtual_network_peering" "network_peering_up" {
  count                        = var.networkPeering.enable ? length(local.virtualNetworks) - 1 : 0
  name                         = "${local.virtualNetworks[count.index].name}.${local.virtualNetworks[count.index + 1].name}"
  resource_group_name          = azurerm_resource_group.network.name
  virtual_network_name         = local.virtualNetworks[count.index].name
  remote_virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.virtualNetworks[count.index + 1].name}"
  allow_virtual_network_access = var.networkPeering.allowRemoteNetworkAccess
  allow_forwarded_traffic      = var.networkPeering.allowRemoteForwardedTraffic
  allow_gateway_transit        = contains(local.virtualGatewayNetworkNames, local.virtualNetworks[count.index].name)
  depends_on = [
    azurerm_subnet_network_security_group_association.network
  ]
}

resource "azurerm_virtual_network_peering" "network_peering_down" {
  count                        = var.networkPeering.enable ? length(local.virtualNetworks) - 1 : 0
  name                         = "${local.virtualNetworks[count.index + 1].name}.${local.virtualNetworks[count.index].name}"
  resource_group_name          = azurerm_resource_group.network.name
  virtual_network_name         = local.virtualNetworks[count.index + 1].name
  remote_virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.virtualNetworks[count.index].name}"
  allow_virtual_network_access = var.networkPeering.allowRemoteNetworkAccess
  allow_forwarded_traffic      = var.networkPeering.allowRemoteForwardedTraffic
  allow_gateway_transit        = contains(local.virtualGatewayNetworkNames, local.virtualNetworks[count.index + 1].name)
  depends_on = [
    azurerm_subnet_network_security_group_association.network
  ]
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_zone" "render" {
  name                = var.privateDns.zoneName
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name                  = each.value.name
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.render.name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}"
  registration_enabled  = var.privateDns.enableAutoRegistration
  depends_on = [
    azurerm_virtual_network.network
  ]
}

###############################################################################################
# Private Endpoint (https://learn.microsoft.com/azure/private-link/private-endpoint-overview) #
###############################################################################################

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "storage_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "${local.computeNetwork.name}.vault"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name                  = "${each.value.name}.blob"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name                  = "${each.value.name}.file"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file.name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}"
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "${data.azurerm_key_vault.render.name}.vault"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  subnet_id           = "${azurerm_private_dns_zone_virtual_network_link.key_vault.virtual_network_id}/subnets/${local.computeNetwork.subnets[local.computeNetwork.subnetIndex.storage].name}"
  private_service_connection {
    name                           = data.azurerm_key_vault.render.name
    private_connection_resource_id = data.azurerm_key_vault.render.id
    is_manual_connection           = false
    subresource_names = [
      "vault"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_key_vault.render.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.key_vault.id
    ]
  }
  depends_on = [
    azurerm_subnet.network
  ]
}

resource "azurerm_private_endpoint" "storage_blob" {
  for_each = {
    for storageSubnet in local.storageSubnets : storageSubnet.name => storageSubnet
  }
  name                = "${data.azurerm_storage_account.render.name}.blob"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  subnet_id           = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
  private_service_connection {
    name                           = data.azurerm_storage_account.render.name
    private_connection_resource_id = data.azurerm_storage_account.render.id
    is_manual_connection           = false
    subresource_names = [
      "blob"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_storage_account.render.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.storage_blob.id
    ]
  }
  depends_on = [
    azurerm_private_endpoint.key_vault
  ]
}

resource "azurerm_private_endpoint" "storage_file" {
  for_each = {
    for storageSubnet in local.storageSubnets : storageSubnet.name => storageSubnet
  }
  name                = "${data.azurerm_storage_account.render.name}.file"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  subnet_id           = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
  private_service_connection {
    name                           = data.azurerm_storage_account.render.name
    private_connection_resource_id = data.azurerm_storage_account.render.id
    is_manual_connection           = false
    subresource_names = [
      "file"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_storage_account.render.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.storage_file.id
    ]
  }
  depends_on = [
    azurerm_private_endpoint.storage_blob
  ]
}

########################################################################
# Bastion (https://learn.microsoft.com/azure/bastion/bastion-overview) #
########################################################################

resource "azurerm_network_security_group" "bastion" {
  count               = var.bastion.enable ? 1 : 0
  name                = "Bastion"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  security_rule {
    name                       = "AllowInHTTPS"
    priority                   = 2000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }
  security_rule {
    name                       = "AllowInGatewayManager"
    priority                   = 2100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }
  security_rule {
    name                       = "AllowInBastion"
    priority                   = 2200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_ranges = [
      "8080",
      "5701"
    ]
  }
  security_rule {
    name                       = "AllowInLoadBalancer"
    priority                   = 2300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "AzureLoadBalancer"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }
  security_rule {
    name                       = "AllowOutSSH[RDP]"
    priority                   = 2000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_ranges = [
      "22",
      "3389"
    ]
  }
  security_rule {
    name                       = "AllowOutAzureCloud"
    priority                   = 2100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "AzureCloud"
    destination_port_range     = "443"
  }
  security_rule {
    name                       = "AllowOutBastion"
    priority                   = 2200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_ranges = [
      "8080",
      "5701"
    ]
  }
  security_rule {
    name                       = "AllowOutBastionSession"
    priority                   = 2300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "Internet"
    destination_port_range     = "80"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  count                     = var.bastion.enable ? 1 : 0
  subnet_id                 = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}/subnets/AzureBastionSubnet"
  network_security_group_id = azurerm_network_security_group.bastion[0].id
  depends_on = [
    azurerm_subnet.network
  ]
}

resource "azurerm_public_ip" "bastion_address" {
  count               = var.bastion.enable ? 1 : 0
  name                = "Bastion"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_subnet_network_security_group_association.bastion
  ]
}

resource "azurerm_bastion_host" "compute" {
  count                  = var.bastion.enable ? 1 : 0
  name                   = "Bastion"
  resource_group_name    = azurerm_resource_group.network.name
  location               = azurerm_resource_group.network.location
  sku                    = var.bastion.sku
  scale_units            = var.bastion.scaleUnitCount
  file_copy_enabled      = var.bastion.enableFileCopy
  copy_paste_enabled     = var.bastion.enableCopyPaste
  ip_connect_enabled     = var.bastion.enableIpConnect
  tunneling_enabled      = var.bastion.enableTunneling
  shareable_link_enabled = var.bastion.enableShareableLink
  ip_configuration {
    name                 = "ipConfig"
    public_ip_address_id = azurerm_public_ip.bastion_address[0].id
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}/subnets/AzureBastionSubnet"
  }
  depends_on = [
    azurerm_subnet_nat_gateway_association.compute,
    azurerm_nat_gateway_public_ip_association.compute
  ]
}

##########################################################################################################################
# Network Address Translation (NAT) Gateway (https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-overview) #
##########################################################################################################################

resource "azurerm_public_ip" "nat_gateway_address_compute" {
  count               = var.natGateway.enable ? 1 : 0
  name                = azurerm_nat_gateway.compute[0].name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "nat_gateway_address_storage" {
  count               = local.storageNetwork.name != "" && var.natGateway.enable ? 1 : 0
  name                = azurerm_nat_gateway.storage[0].name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_nat_gateway" "compute" {
  count               = var.natGateway.enable ? 1 : 0
  name                = "${local.computeNetwork.name}.Gateway"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway" "storage" {
  count               = local.storageNetwork.name != "" && var.natGateway.enable ? 1 : 0
  name                = "${local.storageNetwork.name}.Gateway"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "compute" {
  count                = var.natGateway.enable ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.compute[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_address_compute[0].id
}

resource "azurerm_nat_gateway_public_ip_association" "storage" {
  count                = local.storageNetwork.name != "" && var.natGateway.enable ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.storage[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_address_storage[0].id
}

resource "azurerm_subnet_nat_gateway_association" "compute" {
  for_each = {
    for virtualNetworkSubnet in local.computeNetworkSubnets : virtualNetworkSubnet.name => virtualNetworkSubnet if var.natGateway.enable
  }
  nat_gateway_id = azurerm_nat_gateway.compute[0].id
  subnet_id      = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
}

resource "azurerm_subnet_nat_gateway_association" "storage" {
  for_each = {
    for virtualNetworkSubnet in local.storageNetworkSubnets : virtualNetworkSubnet.name => virtualNetworkSubnet if var.natGateway.enable
  }
  nat_gateway_id = azurerm_nat_gateway.storage[0].id
  subnet_id      = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
}

#################################################
# Virtual Network Gateway (Public IP Addresses) #
#################################################

resource "azurerm_public_ip" "vnet_gateway_address1" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.name => virtualNetwork if var.networkGateway.type != ""
  }
  name                = local.virtualGatewayActiveActive ? "${each.value.name}1" : "${each.value.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "vnet_gateway_address2" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.name => virtualNetwork if local.virtualGatewayActiveActive
  }
  name                = "${each.value.name}2"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "vnet_gateway_address3" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.name => virtualNetwork if local.virtualGatewayActiveActive && length(var.vpnGateway.pointToSiteClient.addressSpace) > 0
  }
  name                = "${each.value.name}3"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
}

#################################
# Virtual Network Gateway (VPN) #
#################################

resource "azurerm_virtual_network_gateway" "vpn" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.name => virtualNetwork if var.networkGateway.type == "Vpn"
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  type                = var.networkGateway.type
  sku                 = var.vpnGateway.sku
  vpn_type            = var.vpnGateway.type
  generation          = var.vpnGateway.generation
  enable_bgp          = var.vpnGateway.enableBgp
  active_active       = local.virtualGatewayActiveActive
  ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}${local.virtualGatewayActiveActive ? "1" : ""}"
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
  }
  dynamic ip_configuration {
    for_each = local.virtualGatewayActiveActive ? [1] : []
    content {
      name                 = "ipConfig2"
      public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}2"
      subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
    }
  }
  dynamic ip_configuration {
    for_each = local.virtualGatewayActiveActive && length(var.vpnGateway.pointToSiteClient.addressSpace) > 0 ? [1] : []
    content {
      name                 = "ipConfig3"
      public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}3"
      subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
    }
  }
  dynamic vpn_client_configuration {
    for_each = length(var.vpnGateway.pointToSiteClient.addressSpace) > 0 ? [1] : []
    content {
      address_space = var.vpnGateway.pointToSiteClient.addressSpace
      root_certificate {
        name             = var.vpnGateway.pointToSiteClient.certificateName
        public_cert_data = var.vpnGateway.pointToSiteClient.certificateData
      }
    }
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.vnet_gateway_address1,
    azurerm_public_ip.vnet_gateway_address2,
    azurerm_public_ip.vnet_gateway_address3
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_up" {
  count                           = var.networkGateway.type == "Vpn" ? length(local.virtualGatewayNetworks) - 1 : 0
  name                            = "${local.virtualGatewayNetworks[count.index].name}.${local.virtualGatewayNetworks[count.index + 1].name}"
  resource_group_name             = azurerm_resource_group.network.name
  location                        = local.virtualGatewayNetworks[count.index].regionName
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index].name}"
  peer_virtual_network_gateway_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index + 1].name}"
  shared_key                      = data.azurerm_key_vault_secret.gateway_connection.value
  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_down" {
  count                           = var.networkGateway.type == "Vpn" ? length(local.virtualGatewayNetworks) - 1 : 0
  name                            = "${local.virtualGatewayNetworks[count.index + 1].name}.${local.virtualGatewayNetworks[count.index].name}"
  resource_group_name             = azurerm_resource_group.network.name
  location                        = local.virtualGatewayNetworks[count.index + 1].regionName
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index + 1].name}"
  peer_virtual_network_gateway_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index].name}"
  shared_key                      = data.azurerm_key_vault_secret.gateway_connection.value
  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

##########################################################################################################################
# Local Network Gateway (VPN) (https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng) #
##########################################################################################################################

resource "azurerm_local_network_gateway" "vpn" {
  count               = var.networkGateway.type == "Vpn" && (var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "") ? 1 : 0
  name                = local.computeNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = local.computeNetwork.regionName
  gateway_fqdn        = var.vpnGatewayLocal.address == "" ? var.vpnGatewayLocal.fqdn : null
  gateway_address     = var.vpnGatewayLocal.fqdn == "" ? var.vpnGatewayLocal.address : null
  address_space       = var.vpnGatewayLocal.addressSpace
  dynamic bgp_settings {
    for_each = var.vpnGatewayLocal.bgp.enable ? [1] : []
    content {
      asn                 = var.vpnGatewayLocal.bgp.asn
      peer_weight         = var.vpnGatewayLocal.bgp.peerWeight
      bgp_peering_address = var.vpnGatewayLocal.bgp.peeringAddress
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "site_to_site" {
  count                      = var.networkGateway.type == "Vpn" && (var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "") ? 1 : 0
  name                       = local.computeNetwork.name
  resource_group_name        = azurerm_resource_group.network.name
  location                   = local.computeNetwork.regionName
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[count.index].id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn[count.index].id
  shared_key                 = data.azurerm_key_vault_secret.gateway_connection.value
  enable_bgp                 = var.vpnGatewayLocal.bgp.enable
}

##########################################
# Virtual Network Gateway (ExpressRoute) #
##########################################

resource "azurerm_virtual_network_gateway" "express_route" {
  count               = var.networkGateway.type == "ExpressRoute" ? 1 : 0
  name                = local.computeNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = local.computeNetwork.regionName
  type                = var.networkGateway.type
  sku                 = var.expressRouteGateway.sku
  ip_configuration {
    name                 = "ipConfig"
    public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${local.computeNetwork.name}"
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}/subnets/GatewaySubnet"
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.vnet_gateway_address1
  ]
}

resource "azurerm_virtual_network_gateway_connection" "express_route" {
  count                        = var.networkGateway.type == "ExpressRoute" && var.expressRouteGateway.connection.circuitId != "" ? 1 : 0
  name                         = local.computeNetwork.name
  resource_group_name          = azurerm_resource_group.network.name
  location                     = local.computeNetwork.regionName
  type                         = "ExpressRoute"
  virtual_network_gateway_id   = azurerm_virtual_network_gateway.express_route[count.index].id
  express_route_circuit_id     = var.expressRouteGateway.connection.circuitId
  express_route_gateway_bypass = var.expressRouteGateway.connection.enableFastPath
  authorization_key            = var.expressRouteGateway.connection.authorizationKey
}

######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

resource "azurerm_private_dns_zone" "monitor" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = "privatelink.monitor.azure.com"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "monitor_opinsights_oms" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = "privatelink.oms.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "monitor_opinsights_ods" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = "privatelink.ods.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "monitor_automation" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = "privatelink.agentsvc.azure-automation.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor" {
  count                 = var.monitor.enablePrivateLink ? 1 : 0
  name                  = "${local.computeNetwork.name}.monitor"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor[0].name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_opinsights_oms" {
  count                 = var.monitor.enablePrivateLink ? 1 : 0
  name                  = "${local.computeNetwork.name}.monitor.opinsights.oms"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor_opinsights_oms[0].name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_opinsights_ods" {
  count                 = var.monitor.enablePrivateLink ? 1 : 0
  name                  = "${local.computeNetwork.name}.monitor.opinsights.ods"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor_opinsights_ods[0].name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_automation" {
  count                 = var.monitor.enablePrivateLink ? 1 : 0
  name                  = "${local.computeNetwork.name}.monitor.automation"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor_automation[0].name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetwork.name}"
}

resource "azurerm_private_endpoint" "monitor" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = "${data.azurerm_log_analytics_workspace.render[0].name}.monitor"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  subnet_id           = "${azurerm_private_dns_zone_virtual_network_link.monitor[0].virtual_network_id}/subnets/${local.computeNetwork.subnets[local.computeNetwork.subnetIndex.storage].name}"
  private_service_connection {
    name                           = data.azurerm_log_analytics_workspace.render[0].name
    private_connection_resource_id = data.azurerm_log_analytics_workspace.render[0].id
    is_manual_connection           = false
    subresource_names = [
      "azuremonitor"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_log_analytics_workspace.render[0].name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor[0].id,
      azurerm_private_dns_zone.monitor_opinsights_oms[0].id,
      azurerm_private_dns_zone.monitor_opinsights_ods[0].id,
      azurerm_private_dns_zone.monitor_automation[0].id,
      azurerm_private_dns_zone.storage_blob.id
    ]
  }
  depends_on = [
    azurerm_private_endpoint.storage_file
  ]
}

resource "azurerm_monitor_private_link_scope" "monitor" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = module.global.monitorWorkspace.name
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_monitor_private_link_scoped_service" "monitor" {
  count               = var.monitor.enablePrivateLink ? 1 : 0
  name                = module.global.monitorWorkspace.name
  resource_group_name = azurerm_resource_group.network.name
  linked_resource_id  = data.azurerm_log_analytics_workspace.render[0].id
  scope_name          = azurerm_monitor_private_link_scope.monitor[0].name
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "computeNetwork" {
  value = local.computeNetwork
}

output "storageNetwork" {
  value = local.storageNetwork
}

output "storageEndpointSubnets" {
  value = [
    for virtualNetworksSubnet in local.virtualNetworksSubnets : virtualNetworksSubnet if contains(virtualNetworksSubnet.serviceEndpoints, "Microsoft.Storage")
  ]
}

output "privateDns" {
  value = var.privateDns
}
