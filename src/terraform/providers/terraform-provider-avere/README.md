# avere_vfxt

The provider that manages an [Avere vFXT for Azure](https://aka.ms/averedocs) cluster.

The provider has the following features:
* create / destroy the Avere vFXT cluster
* scale-up / scale-down from 3 to 16 nodes
* add or remove corefilers and junctions
* add or remove Azure Blob Storage cloud core filer
* add global or vserver custom settings
* add targeted custom settings for the junctions
* add proxy and ntp information

# Example Usage

More examples deployable from Azure Cloud Shell can be found in the [Avere vFXT for Azure Examples](../../examples/vfxt/).

```terraform
resource "avere_vfxt" "vfxt" {
    controller_address = "10.0.2.5"
    controller_admin_username = "azureuser"
    // ssh key comes from ~/.ssh/id_rsa otherwise you can specify password
    //controller_admin_password = ""
    
    ntp_servers = ["169.254.169.254"]
    proxy_uri = "http://10.0.254.250:3128"
    cluster_proxy_uri = "http://10.0.254.250:3128"
    
    location = "eastus"
    azure_resource_group = "avere_vfxt_rg"
    azure_network_resource_group = "eastus_network_rg"
    azure_network_name ="eastus_vnet"
    azure_subnet_name = "cloud_cache_subnet"
    vfxt_cluster_name = "vfxt"
    vfxt_admin_password = "ReplacePassword$"
    vfxt_node_count = 3
    node_cache_size = 4096
    
    global_custom_settings = [
        "vcm.alwaysForwardReadSize DL 134217728",
    ]

    vserver_settings = [
        "NfsFrontEndSobuf OG 1048576",
        "rwsize IZ 524288",
    ]

    azure_storage_filer {
        account_name = "unique0azure0storage0account0name"
        container_name = "tools"
        custom_settings = []
        junction_namespace_path = "/animation-tools"
    }

    core_filer {
        name = "animation"
        fqdn_or_primary_ip = "animation-filer.vfxexample.com"
        cache_policy = "Clients Bypassing the Cluster"
        custom_settings = [
            "autoWanOptimize YF 2",
            "nfsConnMult YW 5",
        ]
        junction {
            namespace_path = "/animation"
            core_filer_export = "/animation"
        }
        junction {
            namespace_path = "/textures"
            core_filer_export = "/textures"
        }
    }

    core_filer {
        name = "animation_for_vdi"
        fqdn_or_primary_ip = module.nasfiler1.primary_ip
        cache_policy = "Isolated Cloud Workstation"
        junction {
            namespace_path = "/animation-vdi"
            core_filer_export = "/animation"
        }
    }
}
```

# Argument Reference

The following arguments are supported:
* <a name="controller_address"></a>[controller_address](#controller_address) - (Optional if [run_local](#run_local) is set to true) the ip address of the controller.  This address may be public or private.  If private it will need to be reachable from where terraform is executed.
* <a name="controller_admin_username"></a>[controller_admin_username](#controller_admin_username) - (Optional if [run_local](#run_local) is set to true) the admin username to the controller
* <a name="controller_admin_password"></a>[controller_admin_password](#controller_admin_password) - (Optional) only specify if [run_local](#run_local) is set to false and password is to be used to access the key, instead of the ssh key ~/.ssh/id_rsa
* <a name="run_local"></a>[run_local](#run_local) - (Optional) specifies if terraform is run directly on the controller (or similar machine with vfxt.py, az cli, and averecmd).  This defaults to false, and if false, a minimum of [controller_address](#controller_address) and [controller_admin_username](#controller_admin_username) must be set.
* <a name="location"></a>[location](#location) - (Required) specify the azure region
* <a name="azure_resource_group"></a>[azure_resource_group](#azure_resource_group) - (Required) this is the azure resource group to install the vFXT.  This must be the same resource as the controller, or increase the RBAC scope of the controller's managed identity roles with a different resource group.
* <a name="azure_network_resource_group"></a>[azure_network_resource_group](#azure_network_resource_group) - (Required) this is the resource group of the VNET to where the vFXT will be deployed.
* <a name="azure_network_name"></a>[azure_network_name](#azure_network_name) - (Required) this is the name of the VNET to where the vFXT will be deployed.
* <a name="azure_subnet_name"></a>[azure_subnet_name](#azure_subnet_name) - (Required) this is the name of the subnet to where the vFXT will be deployed.  As a best practice the Avere vFXT should be installed in its own VNET.
* <a name="ntp_servers"></a>[ntp_servers](#ntp_servers) - (Optional) specify up to 3 NTP servers for the Avere to use, otherwise Avere defaults to time.windows.com.
* <a name="timezone"></a>[timezone](#timezone) - (Optional) Specify a timezone defined in the [timezone file](timezone.go).  The default is "UTC".
* <a name="proxy_uri"></a>[proxy_uri](#proxy_uri) - specify the proxy used by `vfxt.py` for the cluster deployment.  The format is usually `https://PROXY_ADDRESS:3128`.  A working example that uses the proxy is described in the [Avere vFXT in a Proxy Environment Example](../../examples/vfxt/proxy).
* <a name="cluster_proxy_uri"></a>[cluster_proxy_uri](#cluster_proxy_uri) - (Optional) specify the proxy used be used by the Avere vFXT cluster.  The format is usually `https://PROXY_ADDRESS:3128`.  A working example that uses the proxy is described in the [Avere vFXT in a Proxy Environment Example](../../examples/vfxt/proxy).
* <a name="image_id"></a>[image_id](#image_id) - (Optional) specify a custom image id for the vFXT.  This is useful when needing to use a bug fix or there is a marketplace outage.  For more information see the [docs on how to create a custom image for the conroller and vfxt](../../examples/vfxt#create-vfxt-controller-from-custom-images).
* <a name="vfxt_cluster_name"></a>[vfxt_cluster_name](#vfxt_cluster_name) - (Required) this is the name of the vFXT cluster that is shown when you browse to the management ip.  To help Avere support, choose a name that matches the Avere's purpose.
* <a name="vfxt_admin_password"></a>[vfxt_admin_password](#vfxt_admin_password) - (Required) the password for the vFXT cluster.
* <a name="vfxt_node_count"></a>[vfxt_node_count](#vfxt_node_count) - (Required) the number of nodes to deploy for the Avere cluster.  The count may be a minimum of 3 and a maximum of 16.  If the cluster is already deployed, this will result in scaling up or down to the node count.  It requires about 15 minutes to delete and add each node in a scale-up or scale-down scenario.
* <a name="node_cache_size"></a>[node_cache_size](#node_cache_size) - (Optional) The cache size in GB to use for each Avere vFXT VM.  The default value is 4096.  
* <a name="global_custom_settings"></a>[global_custom_settings](#global_custom_settings) - (Optional) these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".
* <a name="vserver_settings"></a>[vserver_settings](#vserver_settings) - (Optional) these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".  Do not prefix with the vserver as it is automatically detected.
* [azure_storage_filer](#azure_storage_filer) - (Optional) zero or more storage filer blocks used to specify zero or more [Azure Blob Storage Cloud core filers](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-deploy-plan#cloud-core-filers).
* [core_filer](#core_filer) - (Optional) zero or more storage filer blocks used to specify zero or more [NFS filers](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-deploy-plan#hardware-core-filers)
* <a name="enable_support_uploads"></a>[enable_support_uploads](#enable_support_uploads) - (Optional) This setting defaults to 'false' and by setting to 'true' you agree to the [Privacy Policy](https://privacy.microsoft.com/en-us/privacystatement) of the Avere vFXT.  This enables support exactly as described in the [Enable Support Uploads documentation](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-enable-support).  Avere vFXT for Azure can automatically upload support data about your cluster. These uploads let support staff provide the best possible customer service.
---

A <a name="azure_storage_filer"></a>`azure_storage_filer` block supports the following
* <a name="account_name"></a>[account_name](#account_name) - (Required) specifies the Azure storage account name for the cloud filer.
* <a name="container_name"></a>[container_name](#container_name) - (Required) specifies the Azure storage blob container name to use for the cloud filer.
* <a name="custom_settings_1"></a>[custom_settings](#custom_settings_1) - (Optional) - these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".  Do not prefix with the mass name as it is automatically detected.
* <a name="junction_namespace_path"></a>[junction_namespace_path](#junction_namespace_path) - (Optional) this is the exported namespace from the Avere vFXT.

---

A <a name="core_filer"></a>`core_filer` block supports the following:
* <a name="name"></a>[name](#name) - (Required) the unique name for the core filer
* <a name="fqdn_or_primary_ip"></a>[fqdn_or_primary_ip](#fqdn_or_primary_ip) - (Required)  The primary IP address or fully qualified domain name of the core filer.  This may also be a space-separated list of IP addresses or domain names, where subsequent network names are used in advanced networking configurations.
* <a name="cache_policy"></a>[cache_policy](#cache_policy) - (Required) the cache policy for the core filer. and can be any of the following values:
    | Cache_policy string | Description |
    | --- | --- |
    | "Clients Bypassing the Cluster" | Use this cache policy when some of your clients are mounting the Avere cluster and others are mounting the core filer directly. |
    | "Read Caching" | Use this cache policy when file read performance is the most critical resource of your workflow. |
    | "Read and Write Caching" | Use this cache policy when a balance of read and write performance is desired. |
    | "Full Caching" | Use this cache policy with cloud core filers or to optimize for op reduction to the core filer. |
    | "Isolated Cloud Workstation" | useful for vdi workstations reading and writing to separate locations as described in [Cloud Workstations](../../examples/vfxt/cloudworkstation) |
    | "Collaborating Cloud Workstation" | useful for vdi workstations reading and writing to the same content as described in [Cloud Workstations](../../examples/vfxt/cloudworkstation) |
* <a name="custom_settings_2"></a>[custom_settings](#custom_settings_2) - (Optional) - these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".  Do not prefix with the mass name as it is automatically detected.
* [junction](#junction) - (Required) this specifies the junction block as described below.
 
---

A <a name="junction"></a>`junction` block supports the following:
* <a name="namespace_path"></a>[namespace_path](#namespace_path) - (Required) this is the exported namespace from the Avere vFXT. 
* <a name="core_filer_export"></a>[core_filer_export](#core_filer_export) - (Required) this is the export from the hardware core filer.
 
# Attributes Reference

In addition to all arguments above, the following attributes are exported:
* <a name="vfxt_management_ip"></a>[vfxt_management_ip](#vfxt_management_ip) - this is the Avere vFXT management ip address.
* <a name="vserver_ip_addresses"></a>[vserver_ip_addresses](#vserver_ip_addresses) - these are the list of vserver ip addresses.  Clients will mount to these addresses.
* <a name="node_names"></a>[node_names](#node_names) - these are the node names of the cluster.

# Build the Terraform Provider binary

There are three approaches to access the provider binary:
1. Download from the [releases page](https://github.com/Azure/Avere/releases).
2. Deploy the [jumpbox](../../examples/jumpbox) - the jumpbox automatically builds the provider.
3. Build the binary using the instructions below.

The following build instructions work in https://shell.azure.com, Centos, or Ubuntu:

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

2. If not already installed go, install golang:

    ```bash
    wget https://dl.google.com/go/go1.14.linux-amd64.tar.gz
    tar xvf go1.14.linux-amd64.tar.gz
    mkdir ~/gopath
    echo "export GOPATH=$HOME/gopath" >> ~/.profile
    echo "export PATH=\$GOPATH/bin:$HOME/go/bin:$PATH" >> ~/.profile
    echo "export GOROOT=$HOME/go" >> ~/.profile
    source ~/.profile
    rm go1.14.linux-amd64.tar.gz
    ```

3. build the provider code
    ```bash
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    cd src/github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    go mod download
    go mod tidy
    go build
    mkdir -p ~/.terraform.d/plugins
    cp terraform-provider-avere ~/.terraform.d/plugins
    ```

4. Install the provider `~/.terraform.d/plugins/terraform-provider-avere` to the ~/.terraform.d/plugins directory of your terraform environment.
