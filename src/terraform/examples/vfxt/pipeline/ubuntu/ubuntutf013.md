# Ubuntu Pipeline with Terraform 0.13.*

These instructions show the pipeline steps to deploy a vFXT on a newly deployed Ubuntu

## Step 1: Deploy Ubuntu

Deploy Ubuntu from [Azure Portal](https://portal.azure.com/), or using the main.tf provided in this directory.

## Step 2: Tools

Login to the ubuntu machine, with the default user, and deploy the tools with the following commands:

```bash
# install unzip and jq
sudo apt update
sudo apt install -y unzip jq
# install terraform
wget https://releases.hashicorp.com/terraform/0.13.6/terraform_0.13.6_linux_amd64.zip
sudo unzip terraform_0.13.6_linux_amd64.zip -d /usr/local/bin
rm terraform_0.13.6_linux_amd64.zip
# install az cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# install the vfxt released binary from https://github.com/Azure/Avere
# to build the provider from scratch see: https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#build-the-terraform-provider-binary-on-linux
version=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name | sed -e 's/[^0-9]*\([0-9].*\)$/\1/')
browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "terraform-provider-avere$")
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
wget -O ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version $browser_download_url
chmod 755 ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version
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