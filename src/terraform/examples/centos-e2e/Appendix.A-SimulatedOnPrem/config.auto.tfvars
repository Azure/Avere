# the location of the simulated on-premises infrastructure
onprem_location = "eastus"

# the resource group to hold the on-premises infrastruture
onprem_rg = "tfonprem_rg"

# the on-premises vnet information
address_space      = "172.16.0.0/23"
gateway_subnet     = "172.16.0.0/24"
onprem_subnet_name = "onprem"
onprem_subnet      = "172.16.1.0/24"

# vyos parameters, only used is 1.network output has is_vpn_ipsec set
vyos_image_id            = ""
vyos_static_private_ip_1 = "172.16.0.254"
vyos_static_private_ip_2 = "172.16.0.253"
vyos_asn                 = 64512

# VM access (jumpbox, vyos VM) 
vm_admin_username = "azureuser"
# vm ssh key, leave empty string if not used
ssh_public_key = ""

// the following ephemeral disk size and skus fit the Moana scene
// 0.51GB Standard_E32s_v3 - use if region does not support Lsv2 or Ls
// 1.92TB Standard_L8s_v2
// 3.84TB Standard_L16s_v2
// 7.68TB Standard_L32s_v2
// 0.56TB Standard_L4s
// 1.15TB Standard_L8s
// 1.15TB Standard_L16s
nfs_filer_vm_size     = "Standard_L8s_v2"
nfs_filer_unique_name = "nfsfiler"
nfs_filer_fqdn        = "nfsfiler.rendering.com"
