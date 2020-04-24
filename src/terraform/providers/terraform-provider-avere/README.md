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

More examples can be found in the [Avere vFXT for Azure Examples](../../examples/vfxt/).

```terraform
locals {
    // the region of the deployment
    location = "canadaeast"
    
    // network details
    virtual_network_resource_group = "filer_resource_group"
    virtual_network_name = "rendervnet"
    vfxt_network_subnet_name = "cloud_cache"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "ReplacePassword$"
    // vfxt cache polies
    //  "Clients Bypassing the Cluster"
    //  "Read Caching"
    //  "Read and Write Caching"
    //  "Full Caching"
    //  "Transitioning Clients Before or After a Migration"
    cache_policy = "Clients Bypassing the Cluster"

    // the proxy used by vfxt.py for cluster stand-up and scale-up / scale-down
    proxy_uri = "http://REPLACE:3128"
    // the proxy used by the running vfxt cluster
    cluster_proxy_uri = "http://REPLACE:3128"

    // vfxt and controller image ids, leave this null, unless not using default marketplace
    vfxt_image_id       = ""
}

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
* <a name="controller_address"></a>[controller_address](#controller_address) - the ip address of the controller.  This address may be public or private.  If private it will need to be reachable from where terraform is executed.
* controller_admin_username
* controller_admin_password
* run_local
* location
* platform
* azure_resource_group
* azure_network_resource_group
* azure_network_name
* azure_subnet_name
* ntp_servers
* proxy_uri
* cluster_proxy_uri
* image_id
* vfxt_cluster_name
* vfxt_admin_password
* vfxt_node_count
* global_custom_settings
* vserver_settings
* azure_storage_filer
* core_filer

---

A `azure_storage_filer` block supports the following
* <a name="account_name"></a>[account_name](#account_name)
* container_name
* custom_settings
* junction_namespace_path

---

A `core_filer` block supports the following:
* name
* fqdn_or_primary_ip
* cache_policy
* custom_settings
* junction
 
---

A `junction` block supports the following:
* namespace_path
* core_filer_export
 
# Attributes Reference

In addition to all arguments above, the following attributes are exported:
* vfxt_management_ip
* vserver_ip_addresses
* node_names

# Build the Terraform Provider binary

There are three approaches to get the provider binary:
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
