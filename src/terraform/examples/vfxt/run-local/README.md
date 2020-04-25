# Advanced: Run Locally on the Controller

This examples describes how to run the cluster setup directly from the controller.

This is useful in locked down environments where it is difficult to reach the controller.

## Deployment Instructions

To run the example, execute the [1-filer example](../1-filer), but comment out the avere_vfxt and the last three output variables.

1. once complete, login to the controller, and download the following two files:
```bash
cd
mkdir -p ~/.terraform.d/plugins
wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.6.1/terraform-provider-avere
sudo apt-get install unzip
wget https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip
unzip terraform_0.12.24_linux_amd64.zip
sudo mv terraform /usr/bin
mkdir vfxt
cd vfxt
wget -O main.tf  https://raw.githubusercontent.com/Azure/Avere/master/src/terraform/examples/vfxt/run-local/main.tf
```

2. `vi main.tf` to edit the local variables section at the top of the file, to customize to your preferences.

3. execute `terraform init` in the directory of `main.tf`.

4. execute `terraform apply -auto-approve` to build the vfxt cluster

5. in a separate shell, you can tail the log files in the home directory: `tail -f ~/*.log`

Once installed you will be able to login and use the vFXT cluster according to the vFXT documentation: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-cluster-gui.

Try to scale up and down the cluster, adjust the customer settings, add new junctions, etc, by editing the `main.tf`, and running `terraform apply -auto-approve`.

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the three resource groups created.