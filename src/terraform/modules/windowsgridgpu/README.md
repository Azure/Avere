# Terraform Module: Azure Virtual Machine Running Windows 10 + Nvidia Grid + Teradici PCoIP

This Terraform module deploys an Azure virtual machine that installs Windows 10 + Nvidia Grid + Teradici PCoIP.

The [windowsgridgpu](../../examples/windowsgridgpu) example shows how to deploy this module using Terraform.  The deployment requires access to the internet to download the Nvidia Grid, and Teradici software and takes about 30 minutes to install.

After you have deployed run you can do either of the following:
1. [Capture the VM to an Image](../../examples/houdinienvironment#phase-1-single-frame-render-step-2b-test-single-frame-render-and-capture-images), 
2. or register the the Teradici license with the following powershell: 

```powershell
        Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent\"

        & .\pcoip-register-host.ps1 -RegistrationCode $TeradiciLicenseKey 

        Restart-Service -Name "PCoIPAgent"
```

To connect, you must download the Teradici PCoIP client from https://docs.teradici.com/find/product/cloud-access-software.

To use the client you will connectivity to TCP Ports **443,4172,60443**, and **UDP port 4172**.