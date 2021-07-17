# CacheWarmer Bootstrap Preparation Module

This module prepares the CacheWarmer bootstrap folder on a target NFS file server for the [CacheWarmer](../../../go/cmd/cachewarmer).  The [CacheWarmer for HPC Cache](../../examples/HPC%20Cache/cachewarmer) or the [CacheWarmer for Avere vFXT for Azure](../../examples/vfxt/cachewarmer) examples demonstrate how to use this module.

If the controller or jumpbox does not have internet access, manually prepare the folder using one of the following approaches:

1. Use the cachewarmer release binaries:
    ```bash
    # prepare the bootstrap directory, updating the env vars with your own vars
    export LOCAL_MOUNT_DIR=/b
    export BOOTSTRAP_MOUNT_ADDRESS=192.168.254.244
    export BOOTSTRAP_MOUNT_EXPORT=/data
    export BOOTSTRAP_SUBDIR=/bootstrap
    curl --retry 5 --retry-delay 5 -L --output /tmp/cachewarmer_prepare_bootstrap.sh https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/modules/cachewarmer_prepare_bootstrapdir/cachewarmer_prepare_bootstrap.sh
    chmod +x /tmp/cachewarmer_prepare_bootstrap.sh
    /tmp/cachewarmer_prepare_bootstrap.sh
    ```

1. Build your own cachewarmer:
    ```bash
    # build the cachewarmer, it will correctly set the env vars for the paths
    curl --retry 5 --retry-delay 5 -L --output /tmp/cachewarmer_build.sh https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/modules/cachewarmer_prepare_bootstrapdir/cachewarmer_build.sh
    chmod +x /tmp/cachewarmer_build.sh
    # use '.' to inherit the env vars
    . /tmp/cachewarmer_build.sh
    # prepare the bootstrap directory, updating the env vars with your own vars
    export LOCAL_MOUNT_DIR=/b
    export BOOTSTRAP_MOUNT_ADDRESS=192.168.254.244
    export BOOTSTRAP_MOUNT_EXPORT=/data
    export BOOTSTRAP_SUBDIR=/bootstrap
    curl --retry 5 --retry-delay 5 -L --output /tmp/cachewarmer_prepare_bootstrap.sh https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/modules/cachewarmer_prepare_bootstrapdir/cachewarmer_prepare_bootstrap.sh
    chmod +x /tmp/cachewarmer_prepare_bootstrap.sh
    /tmp/cachewarmer_prepare_bootstrap.sh
    ```
