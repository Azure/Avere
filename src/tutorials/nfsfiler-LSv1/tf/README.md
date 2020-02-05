# Azure Terraform NFS based NAS Core Filer for LSv1

This is the Azure Terraform implementation of an NFS based NAS Filer using the LSv1 series SKU as described on the LS-Series page: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-previous-gen#ls-series.

Here are the steps to use the terraform from cloud shell:

1. open https://shell.azure.com

2. set the correct subscription, replacing your azure subscription id with `AZURE_SUBSCRIPTION_ID`:

```bash
az account set --subscription AZURE_SUBSCRIPTION_ID
```

3. Download the files
```bash
# create base tf directory
mkdir -p tf
cd tf
curl -o installnfs.sh https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/installnfs.sh

# create nasfiler directory
mkdir -p nasfiler
cd nasfiler
curl -o cloud-init.tpl https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/tf/cloud-init.tpl
curl -o main.tf https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/tf/main.tf
curl -o outputs.tf https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/tf/outputs.tf
curl -o terraform.tfvars https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/tf/terraform.tfvars
curl -o variables.tf https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/tf/variables.tf
```

4. edit file `terraform.tfvars`, and set the correct values

5. initialize terraform and apply

```bash
terraform init
terraform apply -auto-approve
``` 
