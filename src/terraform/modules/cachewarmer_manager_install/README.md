# CacheWarmer Manager Install

This module installs the CacheWarmer manager as a linux systemd service by using the manager bootstrap script for the [CacheWarmer](../../../go/cmd/cachewarmer).  Here are examples that use this module:
1. the [CacheWarmer for HPC Cache](../../examples/HPC%20Cache/cachewarmer) or, 
2. the [CacheWarmer for Avere vFXT for Azure](../../examples/vfxt/cachewarmer) demonstrates how to use this module.

It requires the following:
1. SSH access to a linux node with mountable access to the target NFS Server.  This node is usually created by the [controller](../controller3) module.
2. the node must have a service principal in the environment defined.  By default the [controller](../controller3) module has a system assigned managed identity which will meet this requirement.
