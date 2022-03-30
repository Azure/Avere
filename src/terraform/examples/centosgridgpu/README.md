# Azure Virtual Machine Running Gnome + Nvidia Grid + Teradici PCoIP

This deploys an Azure virtual machine that installs Gnome + Nvidia Grid + Teradici PCoIP.

As you build out this destop for artists review the [ISE Hardening Guide for the Virtual Desktop Infrastructure Workflows](https://azure.microsoft.com/mediahandler/files/resourcefiles/azure-virtual-desktop-infrastructure-hardening-guide/azure-virtual_desktop_infrastructure-hardening_guide.pdf).

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

4. `cd src/terraform/examples/centosgridgpu`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to deploy the centos. The deployment requires access to the internet to download the Nvidia Grid, Gnome, and Teradici software and takes about 30 minutes to install.

## Connecting

To connect, you must download the Teradici PCoIP client from https://docs.teradici.com/find/product/cloud-access-software.

To use the client you will connectivity to TCP Ports **443,4172,60443**, and **UDP port 4172**.

If needed, to register the Teradici license run the following command:

```bash
pcoip-register-host --registration-code='REPLACE_WITH_LICENSE_KEY'
```

## Capture Image

After you have deployed and configured your VM you can [capture the VM to an image](../centos-legacy#next-steps-image-capture).  In summary, the steps are:
1. prepare vm by running `sudo waagent -deprovision+user`.
2. In the Portal, on the page for the VM, Click the "Capture" button.

During the capture phase, you may capture to a custom managed image or a [Shared Image Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries).  The Shared Image Gallery allows for easier management of the image across regions.

Next, you can deploy using the script under the winimage directory:

1. `cd src/terraform/examples/centosgridgpu/centosimage`

2. `code main.tf` to edit the local variables section at the top of the file, add your image, and customize your preferences

3. execute `terraform init` in the directory of `main.tf`.

4. execute `terraform apply -auto-approve` to deploy the windows. The deployment requires access to the internet to download the Nvidia Grid, and Teradici software, and domain registrations and takes about 10 minutes to install.

After you have deployed run you can do either of the following:
1. [Capture the VM to an Image](../centos-legacy#next-steps-image-capture), 
2. or ssh to the box, and register the the Teradici license with the following command: 
