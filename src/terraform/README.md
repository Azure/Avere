# Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure

This folder contains Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure.  Terraform 0.12.x is recommended.

# Examples

The examples show how to deploy HPC Cache and Avere vFXT from minimal configurations to 3-node configurations.

1. [HPC Cache](examples/HPC%20Cache)
   1. [no-filer example](examples/HPC%20Cache/no-filers)
   2. [Avere vFXT against 1 IaaS NAS filer example](examples/HPC%20Cache/1-filer)
   3. [Avere vFXT against 3 IaaS NAS filers example](examples/HPC%20Cache/3-filers)
2. [Avere vFXT](examples/vfxt)
   1. [no-filer example](examples/vfxt/no-filers)
   2. [Avere vFXT against 1 IaaS NAS filer example](examples/vfxt/1-filer)
   3. [Avere vFXT against 3 IaaS NAS filers example](examples/vfxt/3-filers)
   4. [Avere vFXT optimized for Houdini](examples/vfxt/HoudiniOptimized)
3. [NFS Filers](examples/nfsfilers)
   1. [L32sv1](examples/nfsfilers/L32sv1)
   2. [L32sv2](examples/nfsfilers/L32sv2)


# Modules

These modules provide core components for use with HPC Cache or Avere vFXT for Azure:

1. [Controller](modules/controller) - the controller deploys a controller that is used to create and manage an Avere vFXT for Azure
2. [Ephemeral Filer](modules/nfs_filer) - the ephemeral filer provides a high IOPs, high throughput filer that can be used for scratch data.
3. [Render Network](modules/render_network) - the render network module creates a sample render network complete with four subnets: cloud cache, filer, and two render node subnets

# Provider

The following provider creates, destroys, and manages an Avere vFXT for Azure:

1. [terraform-provider-avere](providers/terraform-provider-avere)
