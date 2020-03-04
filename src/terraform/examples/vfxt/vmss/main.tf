// customize the simple VM by editing the following local variables
locals {
    vmss_resource_group_name = "vmss_rg"
    location = "eastus"
    unique_name = "uniquename"

    controller_address = "40.76.72.98"
    controller_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    controller_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    controller_key_data = null //"ssh-rsa AAAAB3...."
    
    mount_addresses = [
    "10.0.1.12",
    "10.0.1.13",
    "10.0.1.14",
    ]

    nfs_export_path = "/nfs1data"
    mount_target = "/data"

    vm_count = 2
    vmss_size = "Standard_DS2_v2"

    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "rendervnet"
    virtual_network_subnet_name = "render_clients1"
}

// TODO: test and then add the vFXT or HPC Cache above

// the vmss config module to install the round robin mount
module "vmss_configure" {
    source = "../../../modules/vmss_config"

    node_address = controller_address
    admin_username = local.admin_username
    admin_password = local.admin_password
    ssh_key_data = local.ssh_key_data
    nfs_address = local.mount_addresses[0]
    nfs_export_path = local.nfs_export_path
}

// the VMSS module
module "vmss" {
    source = "../../../modules/vmss_moutable"

    resource_group_name = local.vmss_resource_group_name
    location = local.location
    admin_username = local.controller_username
    admin_password = local.controller_admin_password
    ssh_key_data = local.controller_key_data
    unique_name = local.unique_name
    vm_count = local.vm_count
    vm_size = local.vmss_size
    virtual_network_resource_group = local.virtual_network_resource_group
    virtual_network_name = local.virtual_network_name
    virtual_network_subnet_name = local.virtual_network_subnet_name
    mount_target = local.mount_target
    nfs_export_addresses = local.mount_addresses
    nfs_export_path = local.nfs_export_path
    bootstrap_script_path = module.vdbench_configure.bootstrap_script_path
}