# Terraform Module: Azure Virtual Machine Running Gnome + Nvidia Grid + Teradici PCoIP

This Terraform module deploys an Azure virtual machine that installs Gnome + Nvidia Grid + Teradici PCoIP.

The [centosgridgpu](../../examples/centosgridgpu) example shows how to deploy this module using Terraform.  The deployment requires access to the internet to download the Nvidia Grid, Gnome, and Teradici software and takes about 30 minutes to install.

After you have deployed run you can do either of the following:
1. [Capture the VM to an Image](../../examples/centos#next-steps-image-capture), 
2. or register the the Teradici license with the following command: 

```bash
pcoip-register-host --registration-code='REPLACE_WITH_LICENSE_KEY'
```

To connect, you must download the Teradici PCoIP client from https://docs.teradici.com/find/product/cloud-access-software.

To use the client you will connectivity to TCP Ports **443,4172,60443**, and **UDP port 4172**.