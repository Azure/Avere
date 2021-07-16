# CentOS Pipeline with Terraform 0.12.*

These instructions show the pipeline steps to deploy a vFXT on a newly deployed CentOS

## Step 1: Deploy Centos

Deploy CentOS from [Azure Portal](https://portal.azure.com/), or using the main.tf provided in this directory.

## Step 2: Tools

Login to the CentOS machine, with the default user, and deploy the tools with the following commands:

```bash
# install git and jq
sudo yum install -y epel-release
sudo yum install -y git jq
# install terraform
wget https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip
sudo unzip terraform_0.12.24_linux_amd64.zip -d /usr/local/bin
rm terraform_0.12.24_linux_amd64.zip
# install az cli
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
sudo yum install -y azure-cli

# install the provider
mkdir -p ~/.terraform.d/plugins
# install the vfxt released binary from https://github.com/Azure/Avere
# to build the provider from scratch see: https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#build-the-terraform-provider-binary-on-linux
browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "terraform-provider-avere$")
wget -O ~/.terraform.d/plugins/terraform-provider-avere $browser_download_url
chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
```

## Step 3: Deploy the vFXT

This example assumes the [no-filers](../../no-filers) example.

```bash
# set the service principal variables (service principal created with az ad sp create-for-rbac --name ServicePrincipalName --role Owner)
# alternatively, create a scoped service principal: https://github.com/Azure/Avere/blob/main/src/terraform/examples/vfxt/pipeline/createscopedsp.md
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"
export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"

# set the parameters
export REGION="westus2"
export USERNAME="azureuser2"
export PASSWORD='ReplacePassword!'
export NETWORK_RG="pipeline-nw-rg"
export VFXT_RG="pipeline-vfxt-rg"
export VFXT_PW="vfxt-pw"

# download the no-filers example
mkdir ~/vfxt
cd ~/vfxt
wget -O ./main.tf https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/vfxt/no-filers/main.tf

# update the parameters
sed  -i "s/location = \"eastus\"/location = \"$REGION\"/g" ./main.tf
sed  -i "s/vm_admin_username = \"azureuser\"/vm_admin_username = \"$USERNAME\"/g" ./main.tf
sed  -i "s/vm_admin_password = \"ReplacePassword\$\"/vm_admin_password = \"$PASSWORD\"/g" ./main.tf
sed  -i "s/network_resource_group_name = \"network_resource_group\"/network_resource_group_name = \"$NETWORK_RG\"/g" ./main.tf
sed  -i "s/vfxt_resource_group_name = \"vfxt_resource_group\"/vfxt_resource_group_name = \"$VFXT_RG\"/g" ./main.tf
sed  -i "s/vfxt_cluster_password = \"VFXT_PASSWORD\"/vfxt_cluster_password = \"$VFXT_PW\"/g" ./main.tf
sed  -i "s/location = \"eastus\"/location = \"$REGION\"/g" ./main.tf

# run the deployment
terraform init
# use logging to watch the progress
TF_LOG=INFO terraform apply -auto-approve
```

## Step 4: Destroy the vFXT

```bash
terraform destroy -auto-approve
```