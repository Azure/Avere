# Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure

This folder contains Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure.  Terraform 0.12.x is recommended.

# Examples

The examples show how to deploy HPC Cache, Avere vFXT, and an NFS Filer from minimal configurations to 3-node configurations.

Both HPC Cache and Avere vFXT for Azure provide file caching for high-performance computing (HPC).  We recommend to always choose HPC Cache for greater user manageability and only choose Avere vFXT for Azure for custom scenarios where HPC is unable to fit.  If you need to use Avere vFXT for Azure because of a missing feature in HPC Cache, please submit an issue so we can track and add to HPC Cache.

1. [HPC Cache](examples/HPC%20Cache)
   1. [no-filer example](examples/HPC%20Cache/no-filers)
   2. [HPC Cache mounting Azure Blob Storage cloud core filer example](examples/HPC%20Cache/azureblobfiler)
   3. [HPC Cache mounting 1 IaaS NAS filer example](examples/HPC%20Cache/1-filer)
   4. [HPC Cache mounting 3 IaaS NAS filers example](examples/HPC%20Cache/3-filers)
   5. [HPC Cache mounting an Azure NetApp Files volume](examples/HPC%20Cache/netapp)
   6. [HPC Cache extends Azure NetApp Files across regions](examples/HPC%20Cache/netapp-across-region)
   7. [HPC Cache and VDBench example](examples/HPC%20Cache/vdbench)
   8. [HPC Cache and VMSS example](examples/HPC%20Cache/vmss)
   9. [HPC Cache and CacheWarmer](examples/HPC%20Cache/cachewarmer)
2. [Avere vFXT for Azure](examples/vfxt)
   1. [no-filer example](examples/vfxt/no-filers)
   2. [Avere vFXT mounting Azure Blob Storage cloud core filer example](examples/vfxt/azureblobfiler)
   3. [Avere vFXT mounting 1 IaaS NAS filer example](examples/vfxt/1-filer)
   4. [Avere vFXT mounting 3 IaaS NAS filers example](examples/vfxt/3-filers)
   5. [Avere vFXT mounting an Azure NetApp Files volume](examples/vfxt/netapp)
   6. [Avere vFXT extends Azure NetApp Files across regions](examples/vfxt/netapp-across-region)
   7. [Avere vFXT and VDBench example](examples/vfxt/vdbench)
   8. [Avere vFXT and VMSS example](examples/vfxt/vmss)
   9. [Avere vFXT and CacheWarmer](examples/vfxt/cachewarmer)
3. [Specialized Avere vFXT for Rendering and Artists](examples/vfxt)
   1. [Avere vFXT optimized for Houdini](examples/vfxt/HoudiniOptimized)
   2. [Avere vFXT and Cloud Workstations](examples/vfxt/cloudworkstation)
   3. [Avere vFXT only](examples/vfxt/vfxt-only) - this example is useful for when the cloud environment is already configured.
   4. [Avere vFXT in a Proxy Environment](examples/vfxt/proxy) - this example shows how to deploy the Avere in a locked down internet environment, with a proxy.
   5. [Deploy Avere vFXT directly from the controller](examples/vfxt/run-local) - this example shows how to deploy the Avere directly from the controller.
   6. [Specify a custom VServer IP Range with the Avere vFXT](examples/vfxt/custom-vserver) - this example shows how to specify a custom VServer IP Range with the Avere vFXT.
4. [SecuredImage](examples/securedimage) - shows how to create, upload, and deploy a custom image with an introduction to RBAC, Azure Governance, and Network.
5. [NFS Ephemeral Filer](examples/nfsfiler) - builds high performance NFS filers.
6. [Jumpbox](examples/jumpbox) - this deploys a VM pre-installed with pre-installed with az cli, terraform, golang, and the built avere provider
Security.
7. [Backup Restore](examples/backuprestore) - Backup any FXT or vFXT cluster and build terraform to restore to HPC Cache or Avere vFXT for Azure.
8. [Best Practices for using Azure Virtual Machine Scale Sets (VMSS) or Azure Cycle Cloud for Rendering](examples/vmss-rendering)
9. [Create a Houdini Render Farm On Azure](examples/houdinienvironment) - this walks through a deployment of a Houdini render environment on Azure.
10. [Create an OpenCue managed render farm on Azure](examples/vfxt/opencue) - deploy an end to end render solution on Azure using OpenCue as your render manager.

# Modules

These modules provide core components for use with HPC Cache or Avere vFXT for Azure:

1. [CacheWarmer Build](modules/cachewarmer_build) - build the cache warmer binaries, and build the bootstrap install directory for the CacheWarmer
2. [CacheWarmer Manager Install](modules/cachewarmer_build) - install the cachewarmer manager using the bootstrap install directory created by the CacheWarmer build process.
3. [CacheWarmer Submit Job](modules/cachewarmer_submitjob) - submit the path to warm, and block until it is warmed.
4. [Controller](modules/controller) - the controller deploys a controller that is used to create and manage an Avere vFXT for Azure
5. [Jumpbox](modules/jumpbox) - the jumpbox has the necessary environment for building the [terraform-provider-avere](providers/terraform-provider-avere).  It is also useful for when experimenting in virtual networks where there is no controller.
6. [Ephemeral Filer](modules/nfs_filer) - the ephemeral filer provides a high IOPs, high throughput filer that can be used for scratch data.
7. [Render Network](modules/render_network) - the render network module creates a sample render network complete with five subnets: cloud cache, filer, jumpbox, and two render node subnets
8. [Secure Render Network](modules/render_network_secure) - the secure render network module where the internet is locked down to all subnets but the proxy subnet.  This module creates a sample render network complete with six subnets: cloud cache, filer, jumpbox, two render node subnets, and a proxy subnet.
9. [Proxy](modules/proxy) - this installs a proxy VM running the Squid Proxy.
10. [VD Bench Config](modules/vdbench_config) - this module configures an NFS share with the VDBench install tools.
11. [VMSS Config](modules/vmss_config) - this module configures an NFS share with a round robin mount script.
12. [Mountable VMSS](modules/vmss_mountable) - this deploys a Linux based VMSS and runs a script off an NFS share.

# Provider

The following provider creates, destroys, and manages an Avere vFXT for Azure:

1. [terraform-provider-avere](providers/terraform-provider-avere)
