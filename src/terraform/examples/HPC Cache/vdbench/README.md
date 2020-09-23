# Vdbench - measuring HPC Cache performance

This is a basic setup to generate small and medium sized workloads to test the performance of [Azure HPC Cache](https://azure.microsoft.com/services/hpc-cache/) memory and disk subsystems.  The suggested configuration is 12 x Standard_D2s_v3 clients for each group of 3 vFXT nodes or for each 2 GB/s of throughput capacity in an HPC cache.

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

Before starting, download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html.  To download you will need to create an account with Oracle and accept the license.  Upload to a storage account or something similar where you can create a personal downloadable URL.

1. browse to https://shell.azure.com

1. Ensure you have a private key stored at ~/.ssh/id_rsa under permission 600.  If you don't have an SSH public-private key pair here are [linux/mac OS](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys) and [windows](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/ssh-from-windows) instructions.

   ```bash
   touch ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   # paste in your private key
   code ~/.ssh/id_rsa
   ```

1. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

1. double check your [HPC Cache prerequisites](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-prereqs)

1. get the terraform examples
   ```bash
   mkdir tf
   cd tf
   git init
   git remote add origin -f https://github.com/Azure/Avere.git
   git config core.sparsecheckout true
   echo "src/terraform/*" >> .git/info/sparse-checkout
   git pull origin main
   ```

1. Decide to use either the NFS filer or Azure storage blob test and cd to the directory:
    1. for Azure Storage Blob testing: `cd src/terraform/examples/HPC\ Cache/vdbench/azureblobfiler`
    2. for NFS filer testing: `cd src/terraform/examples/HPC\ Cache/vdbench/nfsfiler`

1. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

1. execute `terraform init` in the directory of `main.tf`.

1. execute `terraform apply -auto-approve` to build the HPC Cache cluster with a 12 node VMSS configured to run VDBench.

## Using vdbench

1. After deployment is complete, login to the jumpbox as specified by the `jumpbox_username` and `jumpbox_address` terraform output variables, and create the [ssh key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys) to be used by vdbench on the jumpbox:

   ```bash
   touch ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   vi ~/.ssh/id_rsa
   ```
2. run `az login` and execute the command from the `vmss_addresses_command` terraform output variable to get one ip address of a VMSS node, and run the following commands to copy the `id_rsa` file, and login to the node, replace USERNAME with the jumpbox username and IP_ADDRESS with ip address of a VMSS node:

   ```bash
   scp ~/.ssh/id_rsa USERNAME@IP_ADDRESS:.ssh/.
   ssh USERNAME@IP_ADDRESS
   ```

3. During installation, `copy_dirsa.sh` was installed to `~/.` on the vdbench client machine, to enable easy copying of your private key to all vdbench clients.  Run `~/copy_idrsa.sh` to copy your private key to all vdbench clients, and to add all clients to the "known hosts" list. (**Note** if your ssh key requires a passphrase, some extra steps are needed to make this work. Consider creating a key that does not require a passphrase for ease of use.)

### Memory test 

1. To run the memory test (approximately 20 minutes), issue the following command:

   ```bash
   cd
   ./run_vdbench.sh inmem.conf uniquestring1
   ```

2. Browse to the Azure HPC Cache resource in the portal to watch the performance metrics. You will see a similar performance chart to the following:

   <img src="../../../../../docs/images/vdbench_inmem_hpc_cache.png">

### On-disk test

1. To run the on-disk test (approximately 40 minutes) issue the following command:

   ```bash
   cd
   ./run_vdbench.sh ondisk.conf uniquestring2
   ```

2. Browse to the Azure HPC Cache resource in the portal to watch the performance metrics. You will see a performance chart similar to the following one:

   <img src="../../../../../docs/images/vdbench_ondisk_hpc_cache.png">
