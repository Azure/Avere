# the cloud network resource group name
cloud_location   = "eastus"
cloud_network_rg = "cloud_rg"

// cloud virtual network settings
cloud_vnet_name     = "vnet"
cloud_address_space = "10.0.0.0/16"

// The cloud gateway subnet to hold the VPN gateway
// Azure requires this to be named "GatewaySubnet" to hold the VPN Gateway
cloud_gateway_subnet_name = "GatewaySubnet"
cloud_gateway_subnet      = "10.0.0.0/24"

// The subnet to hold the cloud vms
cloud_vms_subnet_name = "cloudvms"
cloud_vms_subnet      = "10.0.1.0/24"

// azure gateway settings
// generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
vpngw_generation = "Generation2"
vpngw_sku        = "VpnGw2"

// the vpn secret key, for production, populate this from keyvault
vpn_secret_key = ""

# the onprem network resource group name
onprem_location   = "eastus"
onprem_network_rg = "onprem_rg"

// onprem virtual network settings
onprem_vnet_name     = "vnet"
onprem_address_space = "10.254.0.0/16"

// The onprem gateway subnet to hold the VPN gateway
onprem_gateway_subnet_name = "vyos"
onprem_gateway_subnet      = "10.254.0.0/24"
onprem_gateway_static_ip1  = "10.254.0.254"
onprem_gateway_static_ip2  = "10.254.0.253"

// The subnet to hold the onprem vms
onprem_vms_subnet_name = "onpremvms"
onprem_vms_subnet      = "10.254.1.0/24"

// vm details
vm_admin_username = "azureuser"
vm_admin_password = ""
# leave ssh key empty if not used
vm_ssh_key_data     = ""
cloud_vm_size       = "Standard_D16s_v3"
onprem_vyos_vm_size = "Standard_F8s_v2"
onprem_vm_size      = "Standard_D16s_v3"
vyos_image_id       = ""
onprem_vpn_asn      = 64512
