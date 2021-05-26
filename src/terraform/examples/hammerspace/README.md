# Hammerspace Filer

This example shows how to deploy a Hammerspace filer.

# Hammerspace Licensing

To use this example, please contact a [Hammerspace representative](https://hammerspace.com/contact/) to get access to the Hammerspace Azure Image.

Once you have the Hammerspace Image ID, use the [Hammerspace Image copy instructions](HammerspaceCopyImage.md) to copy the image, and now you will be ready to deploy, and can proceed to the deployment instructions.

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

6. `cd src/terraform/examples/hammerspace`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the nfs filer

Once installed you will be able to connect to the Web UI and configure the Hammerspace Filer.
