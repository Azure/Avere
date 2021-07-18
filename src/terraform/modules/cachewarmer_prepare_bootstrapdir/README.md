# CacheWarmer Bootstrap Preparation Module

This module prepares the CacheWarmer bootstrap folder on a target NFS file server for the [CacheWarmer](../../../go/cmd/cachewarmer).  The [CacheWarmer for HPC Cache](../../examples/HPC%20Cache/cachewarmer) or the [CacheWarmer for Avere vFXT for Azure](../../examples/vfxt/cachewarmer) examples demonstrate how to use this module.

If the controller or jumpbox does not have internet access, manually prepare a folder of an NFS export using the [cachewarmer_prepare_bootstrap.sh](cachewarmer_prepare_bootstrap.sh) script.  The script will need to access the cachewarmer release binaries.  If you want to build your own cachewarmer binaries run the [cachewarmer_build.sh](cachewarmer_build.sh) script.
