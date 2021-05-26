# Advanced: Run Locally on the Controller

This examples describes how to run the cluster setup directly from the controller.

This is useful in locked down environments where it is difficult to reach the controller.

## Deployment Instructions

To run the example, execute the [1-filer example](../1-filer), but comment out the avere_vfxt and the last three output variables.

1. once complete, login to the controller using the "controller_address"

2. install unzip
```bash
sudo apt-get install unzip
```

3. install the provider and terraform and the main.tf file:
```bash
cd
version=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name | sed -e 's/[^0-9]*\([0-9].*\)$/\1/')
browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[0].browser_download_url)
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
wget -O ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version $browser_download_url
chmod 755 ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version
# get terraform
wget https://releases.hashicorp.com/terraform/0.15.0/terraform_0.15.0_linux_amd64.zip
unzip terraform_0.15.0_linux_amd64.zip
sudo mv terraform /usr/bin
rm terraform_0.15.0_linux_amd64.zip
mkdir -p vfxt
cd vfxt
wget -O main.tf  https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/examples/vfxt/run-local/main.tf
```
4. `vi main.tf` to edit the local variables section at the top of the file, to customize to your preferences.

5. execute `terraform init` in the directory of `main.tf`.

6. execute `terraform apply -auto-approve` to build the vfxt cluster

7. in a separate shell, you can tail the log files in the home directory: `tail -f ~/*.log`

Once installed you will be able to login and use the vFXT cluster according to the vFXT documentation: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-cluster-gui.

Try to scale up and down the cluster, adjust the customer settings, add new junctions, etc, by editing the `main.tf`, and running `terraform apply -auto-approve`.

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the three resource groups created.