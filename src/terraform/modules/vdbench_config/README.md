# VDBench Setup Module

This module sets up the VDBench module.  The [vdbench for HPC Cache](../../examples/HPC%20Cache/vdbench) or the [vdbench for Avere vFXT for Azure](../../examples/vfxt/vdbench) examples demonstrate how to use this module.

It requires the following:
1. SSH access to a node with mountable access to the target NFS Server.  Both the [controller](../nfs_filer) and [jumpbox](../controller) modules achieve this.
2. the node must have internet access.
3. a url to the vdbench zip binary.
