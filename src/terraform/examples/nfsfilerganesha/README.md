# Azure Terraform NFS based IaaS NAS Filer using NFS-Ganesha

This example shows how to use the nfs filer module to deploy Azure Terraform NFS based IaaS NAS Filer using [NFS-Ganesha](https://github.com/nfs-ganesha/nfs-ganesha).

The mode `offline_mode` can be set to true to destroy the VM and downgrade the disk to standard to ensure maximum cost savings during when there is no demand.  Then  set `offline_mode` back to true to create the disk and get it running again.

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
git pull origin main
```

6. `cd src/terraform/examples/nfsfilermd`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the nfs filer

Once installed you will be able to mount the nfs filer.

Test toggling the `offline_mode` variable to see that it destroys the VM and downgrades the disk when turned off. For example, execute `terraform apply -auto-approve -var="offline_mode=true"` to toggle, and then `terraform apply -auto-approve` to toggle back.

When you are done using the filer, you can destroy it by running `terraform destroy -auto-approve`.