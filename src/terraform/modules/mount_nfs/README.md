# VMSS Bootstrap Setup Module

This module installs the mount bootstrap script for VMSS.  The [VMSS for HPC Cache](../../examples/HPC%20Cache/vmss) or the [VMSS for Avere vFXT for Azure](../../examples/vfxt/vmss) examples demonstrate how to use this module.

It requires the following:
1. SSH access to a node with mountable access to the target NFS Server.  Both the [controller](../controller3) and [jumpbox](../jumpbox) modules achieve this.
2. the node must have internet access.
