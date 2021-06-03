[![Build Status - Terraform](https://dev.azure.com/averevfxt/vfxt-github/_apis/build/status/Terraform%20vFXT?branchName=main)](https://dev.azure.com/averevfxt/vfxt-github/_build/latest?definitionId=3&branchName=main)

# VFX and Animation Rendering with HPC Cache and Avere vFXT on Azure

To meet tight deadlines and reduce total cost of ownership (TCO), VFX and Animation studios use Azure for on-demand access to compute capacity for their render workloads.  Avere technology enables the cloud burst rendering scenario and makes it easy to extend an on-premises rendering pipeline to Azure with minimal workflow changes.

Customers burst render to Azure for the main reasons of controlling and tracking costs, security, ease of use, and collaboration.  The [Azure rendering white paper](https://azure.microsoft.com/en-us/resources/visual-effects-and-animation-rendering-in-azure/) goes into detail on each of these topics.

The common cloud burst rendering architecture is shown in the following diagram:

![Burst Rendering Architecture](burstrenderarchitecture.png)

There are 4 major cloud infrastructure components that make up a cloud rendering solution:
1. **Network connection** - the burst rendering solution is connected via an [Azure Virtual Private Network (VPN) Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) or an [Azure ExpressRoute](https://azure.microsoft.com/en-us/services/expressroute/).
1. **Custom Image** - customers create a linux or Windows based custom image that contains the necessary rendering and render management software to mount the storage cache and also connect to on-premises services such as a render manager, AD server, and metrics server.
1. **Storage Cache** - a managed HPC Cache or Avere vFXT is used to cache data, and hide latency to on-premises data.
1. **Render Farm** - Virtual Machine Scalesets are used to scale the custom image across thousands of virtual machines.  Additionally [Azure Cycle Cloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/) is used to help manage the virtual machine scale-sets.

To get started the recommended approach is to follow the [First Render Pilot](examples/securedimage/Azure%20First%20Render%20Pilot.pdf).  The first render pilot provides a phased approach to  build out the burst rendering architecture on Azure.  The resources below will help you through each of the phases.

## Learning

There are multiple video resources to help with learning about burst rendering on Azure:

| Description  | Video Link  |
|---|---|
| [Siggraph 2020 Videos](https://siggraph.event.microsoft.com/) - Six videos from Siggraph 2020 review customer solutions and why render on Azure.  | [![Siggraph 2020 Videos](siggraph2020.png)](https://siggraph.event.microsoft.com/)   |
| [Securing a custom image](https://youtu.be/CNiQU9qbMDk) - This example shows an Azure administrator how to take an on-prem image, upload it to Azure, and then provide secure access to a contributor.  | [![Tutorial Video](examples/securedimage/renderpilot.png)](https://youtu.be/CNiQU9qbMDk)  |
| [Avere vFXT in a Proxy Environment](https://youtu.be/lxDDwu44OHM) - This example shows how to configure an Avere vFXT in a secured locked down internet environment where access to outside resources is via a proxy.  | [![Tutorial Video](examples/vfxt/proxy/proxyyoutube.png)](https://youtu.be/lxDDwu44OHM)  |
| [Making movie magic more affordable](https://customers.microsoft.com/en-us/story/jellyfishpictures) - By using Azure HPC resources, Jellyfish can bid on bigger jobs, better meet deadlines, and reduce capital and labor costs. | [![Making movie magic more affordable](https://ms-f7-sites-01-cdn.azureedge.net/docs/stories/jellyfishpictures/resources/6601324a-047e-488b-bbc5-bad3173f1b0f/1105644140099490900)](https://customers.microsoft.com/en-us/story/jellyfishpictures) |
| [Visual Effects and Animation Rendering in Azure](https://azure.microsoft.com/en-us/resources/visual-effects-and-animation-rendering-in-azure/) | [Whitepaper](https://azure.microsoft.com/en-us/resources/visual-effects-and-animation-rendering-in-azure/) |
| [Head-Turning Animation: ‘Bobbleheads: The Movie’ First Feature Completed Remotely on Microsoft Azure Using NVIDIA GPUs](https://blogs.nvidia.com/blog/2020/12/09/bobbleheads-the-movie/) - With post-production struck by the COVID-19 pandemic, Threshold Entertainment and Incessant Rain Studios use the cloud to bring 3D animators and VFX artists together from around the world. | [Blog Link](https://blogs.nvidia.com/blog/2020/12/09/bobbleheads-the-movie/) |
| [GitOps for Azure Rendering](https://techcommunity.microsoft.com/t5/azure-storage/gitops-for-azure-rendering/ba-p/1326920) | [Blog](https://techcommunity.microsoft.com/t5/azure-storage/gitops-for-azure-rendering/ba-p/132692) |

The remainder of this page provides Terraform infrastructure examples to build out the rendering architecture:
1. [Full End-To-End Examples](#full-end-to-end-examples) - Full end to end examples in Linux and Windows.
1. [Rendering Best Practices for Azure Compute, Network, and Storage](#rendering-best-practices-for-azure-compute-network-and-storage) - learn about the best practices for rendering to reduce TCO on Compute, Network, and Storage.
1. [Storage Cache Infrastructure](#storage-cache-infrastructure) - Use HPC Cache 
1. [Rendering Accessories Infrastructure](#rendering-accessories-infrastructure) - this provides examples of a dns server, NFS ephemeral filer, secure image, and jumpbox.
1. [Terraform Modules](#terraform-modules) - these are the common infrastructure building blocks that make up the rendering architecture.
1. [Avere vFXT Terraform Provider](#avere-vfxt-terraform-provider) - this is the resource page that provides the full reference to using the Avere vFXT Terraform provider.

## Full End-To-End Examples

The following examples provide end-to-end examples that implement the burst rendering architecture in Linux and Windows environments.

1. [Create a Linux based OpenCue managed render farm on Azure](examples/vfxt/opencue) - deploy an end to end render solution on Azure using OpenCue as your render manager.
1. [Create a CentOS Custom  Image and scale on Azure](examples/centos) - shows how to create, upload, and deploy a centos custom image and then scale the image using VMSS.
1. [Create a Windows Render Farm On Azure](examples/houdinienvironment) - this walks through a deployment of a Houdini render environment on Azure.
1. [Create a multi-region render farm with a Hammerspace global file system on Azure](examples/hammerspace-multi-region) - this walks through a deployment of a Houdini render environment on Azure.

## Rendering Best Practices for Azure Compute, Network, and Storage

The highest priority for VFX and Animation Studios is the lowest total cost of ownership (TCO).  The following best practices supplement existing Azure documentation with guidance on how to achieve the lowest TCO.

1. [Best Practices for a New Subscription](examples/new-subscription) - it may be useful for a studio to create a subscription for each office, or each new show to separate out billing.  If this is the case, we recommend creating a one-time process described in this document.
1. [Best Practices for using Azure Virtual Machine Scale Sets (VMSS) or Azure Cycle Cloud for Rendering](examples/vmss-rendering)
1. [Networking Best Practices for Rendering](examples/network-rendering)
1. [Storage Cache Best Practices for Rendering](examples/storagecache-rendering)
1. [Security Best Practices for Rendering](examples/security)
1. [Support Best Practices for Rendering](support.md) - describes what to do when you encounter an issue on Azure.

## Storage Cache Infrastructure

Both HPC Cache and Avere vFXT for Azure provide file caching for high-performance computing (HPC).  We recommend to always choose HPC Cache for greater user manageability and only choose Avere vFXT for Azure for custom scenarios where HPC is unable to fit.  If you need to use Avere vFXT for Azure because of a missing feature in HPC Cache, please submit an issue so we can track and add to HPC Cache.

### HPC Cache

   1. [no-filer example](examples/HPC%20Cache/no-filers)
   1. [HPC Cache mounting Azure Blob Storage cloud core filer example](examples/HPC%20Cache/azureblobfiler)
   1. [HPC Cache mounting 1 IaaS NAS filer example](examples/HPC%20Cache/1-filer)
   1. [HPC Cache mounting 3 IaaS NAS filers example](examples/HPC%20Cache/3-filers)
   1. [HPC Cache mounting an Azure NetApp Files volume](examples/HPC%20Cache/netapp)
   1. [HPC Cache extends Azure NetApp Files across regions](examples/HPC%20Cache/netapp-across-region)
   1. [HPC Cache and VDBench example](examples/HPC%20Cache/vdbench)
   1. [HPC Cache and VMSS example](examples/HPC%20Cache/vmss)
   1. [HPC Cache and CacheWarmer](examples/HPC%20Cache/cachewarmer)
   1. HPC Cache mounting Hammerspace filer example - WIP

### Avere vFXT for Azure

   1. [no-filer example](examples/vfxt/no-filers)
   1. [Avere vFXT mounting Azure Blob Storage cloud core filer example](examples/vfxt/azureblobfiler)
   1. [Avere vFXT mounting 1 IaaS NAS filer example](examples/vfxt/1-filer)
   1. [Avere vFXT mounting 3 IaaS NAS filers example](examples/vfxt/3-filers)
   1. [Avere vFXT mounting an Azure NetApp Files volume](examples/vfxt/netapp)
   1. [Avere vFXT extends Azure NetApp Files across regions](examples/vfxt/netapp-across-region)
   1. [Avere vFXT and VDBench example](examples/vfxt/vdbench)
   1. [Avere vFXT and VMSS example](examples/vfxt/vmss)
   1. [Avere vFXT and CacheWarmer](examples/vfxt/cachewarmer)
   1. [Avere vFXT mounting Hammerspace filer example](examples/vfxt/hammerspace)

### Specialized Avere vFXT for Rendering and Artists](examples/vfxt)

   1. [Avere vFXT optimized for Houdini](examples/vfxt/HoudiniOptimized)
   1. [Avere vFXT and Cloud Workstations](examples/vfxt/cloudworkstation)
   1. [Avere vFXT only](examples/vfxt/vfxt-only) - this example is useful for when the cloud environment is already configured.
   1. [Avere vFXT in a Proxy Environment](examples/vfxt/proxy) - this example shows how to deploy the Avere in a locked down internet environment, with a proxy.
   1. [Deploy Avere vFXT directly from the controller](examples/vfxt/run-local) - this example shows how to deploy the Avere directly from the controller.
   1. [Specify a custom VServer IP Range with the Avere vFXT](examples/vfxt/custom-vserver) - this example shows how to specify a custom VServer IP Range with the Avere vFXT.
   1. [Avere vFXT using User Assigned Managed Identity](examples/vfxt/user-assigned-managed-identity) - this example shows how to use a user assigned managed identity with the Avere vFXT.
   1. [Backup Restore](examples/backuprestore) - Backup any FXT or vFXT cluster and build terraform to restore to HPC Cache or Avere vFXT for Azure.
   1. [Zone Redundant NFS / SMB Storage](examples/vfxt/azureblobfiler-zonal) - Availability Zone Redundant Avere vFXT mounting Blob Storage example

## Rendering Accessories Infrastructure

The following terraform examples build out accessory rendering infrastructure such as DNS Servers, high speed NFS ephemeral filers, and a jumpbox:

### Workstations
1. [Windows 10 + Nvidia Grid + Teradici PCoIP](examples/windowsgridgpu) - this example deploys Windows 10 + Nvidia Grid + Teradici PCoIP.
1. [CentOS7 + Gnome + Nvidia Grid + Teradici PCoIP](examples/centosgridgpu) - this example deploys CentOS7 with Gnome + Nvidia Grid + Teradici PCoIP.

### NFS Filers

1. [NFS Ephemeral Filer](examples/nfsfiler) - builds a very high performance NFS filers for use as a scratch filer.
1. [NFS Managed Disk Filer](examples/nfsfilermd) - builds an NFS Filer with highly available managed disk storage.
1. [NFS Filer using NFS-Ganesha](examples/nfsfilerganesha) - builds high performance NFS filers.
1. [NFS Filer using Hammerspace](examples/hammerspace) - builds a Hammerspace filer capable of spanning across multiple regions.

### DNS, Security, and Jumpbox 

1. [Secure VNET](examples/securevnet) - shows how to create a simple secure VNET that has locked down internet for burst render.
1. [DNS Server to Override Filer Address](examples/dnsserver) - This deploys an Azure virtual machine that installs and configures [Unbound](https://nlnetlabs.nl/projects/unbound/about/) and and configures it to override the address of an on-premises filer so that the render nodes mount the Avere to hide the latency.  All other dns requests are forwarded to pre-configured on-premises dns servers.
1. [SecuredImage](examples/securedimage) - shows how to create, upload, and deploy a custom image with an introduction to RBAC, Azure Governance, and Network.
1. [Jumpbox](examples/jumpbox) - this deploys a VM pre-installed with pre-installed with az cli, terraform, golang, and the built avere provider
Security.

## Terraform Modules

These modules provide core components for use with HPC Cache or Avere vFXT for Azure:

### Network

1. [Render Network](modules/render_network) - the render network module creates a sample render network complete with five subnets: cloud cache, filer, jumpbox, and two render node subnets
1. [Secure Render Network](modules/render_network_secure) - the secure render network module where the internet is locked down to all subnets but the proxy subnet.  This module creates a sample render network complete with six subnets: cloud cache, filer, jumpbox, two render node subnets, and a proxy subnet.
1. [Proxy](modules/proxy) - this installs a proxy VM running the Squid Proxy.
1. [DNS Server](modules/dnsserver) - this installs a DNS Server to be used with HPC Cache or Avere vFXT.

### Compute

1. [Mountable VMSS](modules/vmss_mountable) - this deploys a Linux based VMSS and runs a script off an NFS share.
1. [Azure CycleCloud](modules/cyclecloud) - this deploys an Azure CycleCloud instance.
1. [VMSS Mount Script](modules/mount_nfs) - This module installs the mount bootstrap script for VMSS.
1. [VD Bench Config Script](modules/vdbench_config) - this module configures an NFS share with the VDBench install tools.
1. [VMSS Config Script](modules/vmss_config) - this module configures an NFS share with a round robin mount script.
1. [Opencue Config Script](modules/opencue_config) - this module sets up the OpenCue RQD clients module.
1. [Gnome + Nvidia Grid + Teradici PCoIP](modules/centosgridgpu) - this module deploys Gnome + Nvidia Grid + Teradici PCoIP.

### Controller and Jumpbox

1. [Controller3](modules/controller3) - Deploys a python 3 controller that is used to create and manage an Avere vFXT for Azure.
1. Controller - (Deprecated) Deploys a python 2 controller that is used to create and manage an Avere vFXT for Azure.
1. [Jumpbox](modules/jumpbox) - the jumpbox has the necessary environment for building the [terraform-provider-avere](providers/terraform-provider-avere).  It is also useful for when experimenting in virtual networks where there is no controller.

### NFS Filers

1. [NFS Ephemeral Filer](modules/nfs_filer) - the NFS ephemeral filer provides a high IOPs, high throughput filer that can be used for scratch data.
1. [NFS Managed Disk Filer](modules/nfs_filer_md) - the NFS managed disk filer provides NFS access to highly available storage.  There is an offline mode to destroy the VM and cool the storage for maximum cost savings when not in use.
1. [NFS-Ganesha Filer](modules/nfs_filer_ganesha) - the NFS-Ganesha provides a user space NFS Server and provides NFS access to highly available storage.  There is an offline mode to destroy the VM and cool the storage for maximum cost savings when not in use.
1. [Hammerspace Anvil](modules/hammerspace/anvil) - the Hammerspace Anvil module deploys a Standalone or Highly Available Hammerspace Anvil cluster.
1. [Hammerspace DSX](modules/hammerspace/dsx) - the Hammerspace DSX module deploys a configurable number of Hammerspace DSX nodes.

### Cache Warmer

1. [CacheWarmer Build](modules/cachewarmer_build) - build the cache warmer binaries, and build the bootstrap install directory for the CacheWarmer
1. [CacheWarmer Manager Install](modules/cachewarmer_manager_install) - install the cachewarmer manager using the bootstrap install directory created by the CacheWarmer build process.
1. [CacheWarmer Submit Job](modules/cachewarmer_submitjob) - submit the path to warm, and block until it is warmed.
1. [CacheWarmer Submit Multiple Jobs](modules/cachewarmer_submitmultiplejobs) - submit multiple jobs to the cachewarmer.

## Avere vFXT Terraform Provider

The following provider creates, destroys, and manages an Avere vFXT for Azure:

* [terraform-provider-avere](providers/terraform-provider-avere)

To add the provider to a pipeline on either Ubuntu or CentOS read the following examples:

* [Building a Pipeline for the vFXT Provider](examples/vfxt/pipeline)
