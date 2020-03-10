# Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure

This folder contains Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure.  Terraform 0.12.x is recommended.

# Examples

The examples show how to deploy HPC Cache, Avere vFXT, and an NFS Filer from minimal configurations to 3-node configurations.

1. [HPC Cache](examples/HPC%20Cache)
   1. [no-filer example](examples/HPC%20Cache/no-filers)
   2. [HPC Cache mounting 1 IaaS NAS filer example](examples/HPC%20Cache/1-filer)
   3. [HPC Cache mounting 3 IaaS NAS filers example](examples/HPC%20Cache/3-filers)
   4. [HPC Cache and VDBench example](examples/HPC%20Cache/vdbench)
   5. [HPC Cache and VMSS example](examples/HPC%20Cache/vmss)
2. [Avere vFXT](examples/vfxt)
   1. [no-filer example](examples/vfxt/no-filers)
   2. [Avere vFXT mounting 1 IaaS NAS filer example](examples/vfxt/1-filer)
   3. [Avere vFXT mounting 3 IaaS NAS filers example](examples/vfxt/3-filers)
   4. [Avere vFXT optimized for Houdini](examples/vfxt/HoudiniOptimized)
   5. [Avere vFXT and VDBench example](examples/vfxt/vdbench)
   6. [Avere vFXT and VMSS example](examples/vfxt/vmss)
3. [NFS Ephemeral Filer](examples/nfsfiler)
4. [Jumpbox](examples/jumpbox) - this deploys a VM pre-installed with pre-installed with az cli, terraform, golang, and the built avere provider

# Modules

These modules provide core components for use with HPC Cache or Avere vFXT for Azure:

1. [Controller](modules/controller) - the controller deploys a controller that is used to create and manage an Avere vFXT for Azure
2. [Jumpbox](modules/jumpbox) - the jumpbox has the necessary environment for building the [terraform-provider-avere](providers/terraform-provider-avere).  It is also useful for when experimenting in virtual networks where there is no controller.
3. [Ephemeral Filer](modules/nfs_filer) - the ephemeral filer provides a high IOPs, high throughput filer that can be used for scratch data.
4. [Render Network](modules/render_network) - the render network module creates a sample render network complete with four subnets: cloud cache, filer, and two render node subnets
5. [VD Bench Config](modules/vdbench_config) - this module configures an NFS share with the VDBench install tools.
6. [VMSS Config](modules/vmss_config) - this module configures an NFS share with a round robin mount script.
7. [Mountable VMSS](modules/) - this deploys a Linux based VMSS and runs a script off an NFS share.

# Provider

The following provider creates, destroys, and manages an Avere vFXT for Azure:

1. [terraform-provider-avere](providers/terraform-provider-avere)
