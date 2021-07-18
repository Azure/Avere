# CacheWarmer Bootstrap Setup Module

This module installs the CacheWarmer bootstrap script for the [CacheWarmer](../../../go/cmd/cachewarmer).  The [CacheWarmer for HPC Cache](../../examples/HPC%20Cache/cachewarmer) or the [CacheWarmer for Avere vFXT for Azure](../../examples/vfxt/cachewarmer) examples demonstrate how to use this module.

It requires the following:
1. SSH access to a node with mountable access to the target NFS Server.  Both the [controller](../controller3) and [jumpbox](../jumpbox) modules achieve this.
2. the node must have internet access.
3. the node must have a service principal in the environment defined.
