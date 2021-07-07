# the location of the simulated on-premises infrastructure
onprem_location = "eastus"

# the resource group to hold the on-premises infrastruture
onprem_rg = "tfonprem_rg"

# the on-premises vnet information
address_space = "172.16.0.0/23"
// DO NOT CHANGE NAME "GatewaySubnet", Azure requires it with that name
gateway_subnet     = "172.16.0.0/24"
onprem_subnet_name = "onprem"
onprem_subnet      = "172.16.1.0/24"

# vyos image id, leave empty string to use Azure VPN
vyos_image_id = ""

# vm ssh key, leave empty string if not used
ssh_public_key = ""

# nfs filer disk size in gb
disk_type    = "Premium_LRS"
disk_size_gb = 127
