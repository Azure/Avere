# Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure

This folder contains Terraform Examples, Modules, and Providers for HPC Cache and Avere vFXT for Azure.  Terraform 0.12.x is recommended.

# Examples

The examples show how to deploy HPC Cache and Avere vFXT from minimal configurations to 3-node configurations.

1. [HPC Cache](examples/HPC%20Cache)
2. [Avere vFXT](examples/vfxt)
   1. [no-filer example](examples/vfxt/no-filers)
   2. [Avere vFXT against 1 IaaS NAS filer example](examples/vfxt/1-filer)
   3. [Avere vFXT against 3 IaaS NAS filers example](examples/vfxt/3-filers)

# Modules

These modules provide core components for use with HPC Cache or Avere vFXT for Azure:

1. [Controller](modules/controller) - the controller deploys a controller that is used to create and manage an Avere vFXT for Azure
2. [Ephemeral Filer](modules/ephemeral_filer) - the ephemeral filer provides a high IOPs, high throughput filer that can be used for scratch data.

# Provider

The following provider creates, destroys, and manages an Avere vFXT for Azure:

1. [terraform-provider-avere](providers/terraform-provider-avere)
