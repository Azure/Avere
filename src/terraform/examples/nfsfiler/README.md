# Azure Terraform NFS based IaaS NAS Filer using ephemeral storage

This example shows how to use the nfs filer module to deploy Azure Terraform NFS based IaaS NAS Filer using ephemeral storage.

The following table shows the performance characteristics of various Azure SKUs:

| Azure SKU | Ephemeral Disk Type | Capacity (TiB) | Storage Throughput (GB/s) | IOPs |
| --- | --- | --- | --- | --- |
| Standard_D2s_v3 (good for POC) | ssd | 0.04 TiB | 0.04 Read GB/s, 0.02 Write GB/s  | 3000 |
| Standard_L4s | ssd | 0.56 TiB | 0.20 GB/s | 20000 |
| Standard_L8s | ssd | 1.15 TiB | 0.39 GB/s | 40000 |
| Standard_L16s | ssd | 2.33 TiB | 0.78 GB/s | 80000 |
| Standard_L32s | ssd | 4.68 TiB | 1.56 GB/s | 160000 |
| Standard_L8s_v2 | nvme | 1.92 TiB | 0.39 GB/s (limited by NIC) | 400000 |
| Standard_L16s_v2 | nvme | 3.84 TiB | 0.78 GB/s (limited by NIC) | 800000 |
| Standard_L32s_v2 | nvme | 7.68 TiB | 1.56 GB/s (limited by NIC) | 1.5M |
| Standard_L48s_v2 | nvme | 11.52 TiB | 1.95 GB/s (limited by NIC) | 2.2M |
| Standard_L64s_v2 | nvme | 15.36 TiB | 1.95 GB/s (limited by NIC) | 2.9M |
| Standard_L80s_v25 | nvme | 19.2 TiB  | 1.95 GB/s (limited by NIC) | 3.8M |
| Standard_M128s | ssd | 4.0 TiB | 1.56 GB/s | 160000 |

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. As a pre-requisite ensure you have a network and the ability to ssh to a private ip address.  If not deploy the [jumpbox example](../jumpbox/).

4. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin master
```

6. `cd src/terraform/examples/nfsfiler`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the HPC Cache cluster

Once installed you will be able to mount the nfs filer.

When you are done using the filer, you can destroy it by running `terraform destroy -auto-approve`.