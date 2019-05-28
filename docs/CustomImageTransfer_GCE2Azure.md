# Transferring custom image from GCE to Azure

When talking to customers about trying out Azure, one sticking point that we often hear is that rebuilding
their workflow (again) in a different cloud is painful. One of the pain points is regarding their VMs - it takes alot of time
and energy to build a new image so even getting started with their apps, scripts, etc is just... hard.... 

There doesn't appear to be an end-to-end guide on how to move a custom image from GCE into Azure for Azure newbies.
In an effort to make the transition from Google GCE to Microsoft Azure easier, I thought it made some sense to test how one 
might do that. 

It's pretty straight-forward and only takes about an hour once you know what to do (and most of that is wait time on the downloading/converting/uploading steps). You'll notice that this is Debian/Ubuntu specific so, if you're using Centos, just substitute "yum" for "apt-get".

Here's how I did it:

# Prepare image

This page gives you just about all you need to prepare the image for Azure:
https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu

---
Important - you should follow the steps on the link above, the immediate steps below on initially preparing the image are what I did at the time and are here for convenience and reference. The link above will be updated with any new changes/requirements: 
```
# sudo apt-get update
# sudo apt-get install linux-generic-hwe-16.04 linux-cloud-tools-generic-hwe-16.04
# sudo apt-get dist-upgrade
# sudo reboot
```

Modify Grub file: 
```
vi /etc/default/grub
```
Edit the following:
```
GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300"
```

Update Grub:
```
sudo update-grub
```

Install Azure Linux Agent:
```
# sudo apt-get update
# sudo apt-get install walinuxagent
```

Create Linux Agent Azure config file
```
/etc/cloud/cloud.cfg.d/90-azure.cfg
```

Contents should look like this:
```
datasource:
   Azure:
     agent_command: [service, walinuxagent, start]
```

Deprovision the VM:
```
# sudo waagent -force -deprovision
# export HISTSIZE=0
# logout
 ```
---

A GCE image, of course, also comes loaded with a bunch of GCE-related goodies that should probably be removed. 

SSHGuard caused me some trouble so I removed that:
```
sudo apt-get remove --purge sshguard
```

Removing these files helped to clean up and quiet-down the logs:
```
cd /
rm etc/apt/apt.conf.d/01autoremove-gce 
rm etc/apt/apt.conf.d/99-gce-ipv4-only 
rm etc/cloud/cloud.cfg.d/91-gce.cfg
rm etc/cloud/cloud.cfg.d/91-gce-system.cfg
rm etc/apt/apt.conf.d/99ipv4-only 
rm etc/modprobe.d/gce-blacklist.conf
rm etc/rsyslog.d/90-google.conf
rm etc/sysctl.d/11-gce-network-security.conf 
rm etc/sysctl.d/99-gce.conf 
rm lib/systemd/system-preset/90-google-compute-engine.preset
rm lib/systemd/system/google-accounts-daemon.service
rm lib/systemd/system/google-clock-skew-daemon.service
rm lib/systemd/system/google-network-daemon.service
rm lib/systemd/system/google-instance-setup.service
rm lib/systemd/system/google-shutdown-scripts.service
rm lib/systemd/system/google-startup-scripts.service
rm lib/udev/rules.d/64-gce-disk-removal.rules
rm lib/udev/rules.d/65-gce-disk-naming.rules
rm lib/udev/rules.d/99-gce.rules
rm usr/bin/google_accounts_daemon
rm usr/bin/google_clock_skew_daemon
rm usr/bin/google_instance_setup
rm usr/bin/google_metadata_script_runner
rm usr/bin/google_network_daemon
rm usr/bin/google_optimize_local_ssd
rm usr/bin/google_set_multiqueue
rm usr/share/doc/gce-compute-image-packages/TODO.Debian
rm usr/share/doc/gce-compute-image-packages/changelog.Debian.gz
rm usr/share/doc/gce-compute-image-packages/copyright
rm usr/share/lintian/overrides/gce-compute-image-packages
```


You will want to disable cloudinit and let waagent do the provisioning from the waagent config file:
```
vi /etc/waagent
```
Make these changes (I disabled the firewall to simplify the installation):
```
# Enable instance creation
Provisioning.Enabled=y
...

# Rely on cloud-init to provision
Provisioning.UseCloudInit=n
...

# Add firewall rules to protect access to Azure host node services
OS.EnableFirewall=n
```

Stop the VM

# Capture the image

Login to the GCE console:
```
$ gcloud auth login
```

List disks in project:
```
$ gcloud compute disks list
NAME                LOCATION    LOCATION_SCOPE  SIZE_GB  TYPE         STATUS
testimage-ubuntu-2  us-east4-c  zone            10       pd-standard  READY
ubuntu-demo         us-east4-c  zone            10       pd-standard  READY
```

Create image in GCE (https://cloud.google.com/sdk/gcloud/reference/beta/compute/images/create)
```
$ gcloud compute images create ubuntu-demo-image --source-disk=ubuntu-demo --source-disk-zone=us-east4-c
```

I needed an easy way to get the image into Azure so I made it publicly accessible by putting it into a public bucket and exporting the image into that bucket.

Make bucket publicly accessible (https://cloud.google.com/storage/docs/access-control/making-data-public)
```
$ gsutil iam ch allUsers:objectViewer gs://mybucket-public/
```

Export image in GCE (https://cloud.google.com/sdk/gcloud/reference/beta/compute/images/export)
```
$ gcloud compute images export --destination-uri=gs://mybucket-public/ubuntu-demo-image.vhdx --image=ubuntu-demo-image --async --export-format=vhdx
```

# Convert VHDX to VHD

Azure supports VHD images, not VHDX. Fortunately, there is a simple PowerShell utility that can convert the image to VHD. If you've been using Hyper-V in your environment, and specifically using Windows, you may already have the utility installed. If you're a Linux-only shop or don't run your own Hyper-V environment, then you'll need to install the tools on a Windows server. 

Here is how I did it:

Log into your Windows Server or spin up a new one in Azure. 

Open PowerShell and install Hyper-V PowerShell Tools (https://redmondmag.com/articles/2018/11/16/installing-hyperv-module-for-powershell.aspx AND https://sid-500.com/2018/01/30/how-to-install-hyper-v-and-create-your-first-vm-with-powershell-hyper-host-switch-hyper-v-guest/)

```
Enable-WindowsOptionalFeature -Online -FeatureName  Microsoft-Hyper-V
Reboot
Install-WindowsFeature Hyper-V -IncludeManagementTools
Get-WindowsFeature *Hyper*
Display Name                                            Name                       Install State
------------                                            ----                       -------------
[X] Hyper-V                                             Hyper-V                        Installed
        [X] Hyper-V Management Tools                    RSAT-Hyper-V-Tools             Installed
            [X] Hyper-V GUI Management Tools            Hyper-V-Tools                  Installed
            [X] Hyper-V Module for Windows PowerShell   Hyper-V-PowerShell             Installed
```

Install Azure PowerShell module (https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-1.6.0)
```
Install-Module -Name Az -AllowClobber
```

Download the image from the GCE public bucket.

Convert VHDX to VHD using PowerShell (https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image#convert-disk-by-using-powershell)

```
Convert-VHD -Path c:\Path\To\Image\ubuntu-demo-image.vhdx -DestinationPath c:\Path\To\Image\ubuntu-demo-image.vhd -VHDType Fixed
```
# Upload to Azure
Let's get the VHD uploaded to Azure. 

Creating a publicly-accessible Blob storage container seems to be the most simplistic approach.

If you're new to Azure, you may want to download the AZ CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). 

For this exercise, I already had a Resource Group created (named 'keep'). Documentation, examples, tutorials on how to do that can be found here: https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create

Create ADLS storage account:
```
Connect-AzAccount
$location = ‘eastus'
$storageaccountname = ‘myvmstore'

New-AzStorageAccount `
>>     -ResourceGroupName keep -Name $storageaccountname -Location $location -SkuName "Standard_LRS" `
>>     -Kind “Storage"
```
Make it public:
```
New-AzStorageContext -StorageAccountName $storageaccountname -Anonymous -Protocol “http"
```
Create a container named 'public' to drop the image into:
```
$containerName = "public"
new-AzStoragecontainer -Name $containerName -Permission blob
```


Uploading the VHD into the new container can be done in a number of different ways. The most efficient is using the Azure AzCopy tool: https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy?toc=%2fazure%2fstorage%2fblobs%2ftoc.json

Install azcopy using the instructions here:
https://aka.ms/downloadazcopy

Now copy the image to Azure:
```
cd 'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\'
.\AzCopy.exe /Source:C:\Path\To\Image\ubuntu-demo-image.vhd /Dest:https://myvmstore.blob.core.windows.net/public/ubuntu-demo-image.vhd /DestKey:/<key here> /BlobType:page
```

# Create VM from VHD
Once the image is in Azure, the process to create the VM is straight-forward. 

Essentially, you will need to:
1. Create an OS Disk from the image
2. Create the VM using the OS Disk

More information can be found here:
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/create-vm-specialized-portal
