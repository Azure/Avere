# the cloud network resource group name
cloud_location   = "eastus"
cloud_network_rg = "cloudwireguard_rg"

// cloud virtual network settings
cloud_vnet_name     = "vnet"
cloud_address_space = "10.0.0.0/16"

// The cloud gateway subnet to hold the VPN gateway
cloud_gateway_subnet_name = "wireguard"
cloud_gateway_subnet      = "10.0.0.0/24"

// The subnet to hold the cloud vms
cloud_vms_subnet_name = "cloudvms"
cloud_vms_subnet      = "10.0.1.0/24"

// the wireguard public and private ips can be configured in two ways:
// 1. generate the pair from https://www.wireguardconfig.com/
// 2. deploy an Ubuntu VM, and generate per page https://www.wireguard.com/quickstart/
cloud_wg_public_key  = ""
cloud_wg_private_key = ""

# the onprem network resource group name
onprem_location   = "eastus"
onprem_network_rg = "onpremwireguard_rg"

// onprem virtual network settings
onprem_vnet_name     = "vnet"
onprem_address_space = "10.254.0.0/16"

// The onprem gateway subnet to hold the VPN gateway
onprem_gateway_subnet_name = "wireguard"
onprem_gateway_subnet      = "10.254.0.0/24"

// The subnet to hold the onprem vms
onprem_vms_subnet_name = "onpremvms"
onprem_vms_subnet      = "10.254.1.0/24"

// the wireguard public and private ips can be configured in two ways:
// 1. generate the pair from https://www.wireguardconfig.com/
// 2. deploy an Ubuntu VM, and generate per page https://www.wireguard.com/quickstart/
onprem_wg_public_key  = ""
onprem_wg_private_key = ""

// To increase throughput, specify the number of tunnels to create 
// between wireguard peers.  This will use ECMP to balance across the
// tunnels where each source/dest pair will have maximum bandwidth of 
// a single tunnel due to source/dest pair hashing.
tunnel_count  = 3
base_udp_port = 5000

// vm details
vm_admin_username   = "azureuser"
vm_admin_password   = "ReplacePassword$"
vm_ssh_key_data     = ""
cloud_wg_vm_size    = "Standard_D2s_v4"
cloud_vm_size       = "Standard_D16s_v3"
onprem_wg_vm_size   = "Standard_D2s_v4"
onprem_vm_size      = "Standard_D16s_v3"
vmss_instance_count = 0
