# Windows 10 workstation for the Avere vFXT 

This 20-minute deployment sets up a Windows 10 workstation with various tools and features for working with the Avere vFXT for Azure.

Setup includes these items: 

* **Avere vFXT mounted volume** - The Avere vFXT volume is automatically mounted to c:\AvereVFXT and a shortcut is placed on the Windows desktop

* **vFXT management links on desktop and Edge** - Adds a desktop shortcut and an Edge browser home button pointing to the vFXT cluster's management interface, Avere Control Panel

* **Media software** - Installs the Windows Media Service Pack and VirtualDub to enable post production of content (including turning rendered frames into movies)

* **Azure Batch Explorer** - Azure Batch Explorer enables easy management and viewing of batch jobs.

* **Azure Storage Explorer** - Azure Storage Explorer allows management of all Azure Storage accounts.

This solution can be deployed through the portal or cloud shell.

## Portal Deployment

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fwin10vfxtmounted%2Fwin10-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>


> Tip: The source code to produce the template is located [here](../src/win10vfxtmounted)

Save the output values of the deployment for access to the workstation.

## Using the Windows 10 workstation

1. RDP to the ``clientAddress`` value saved from the output parameters in the last command.

2. Log in. You should see the following changes:
   * Desktop shortcuts for the Avere Control Panel, mounted Avere volume, Batch Explorer, Storage Explorer, and Virtual Dub
   * The Avere vFXT export is mounted to c:\AvereVFXT
   * Avere Control Panel (vFXT management UI) can be opened with the desktop shortcut or "Home" button

   <img src="images/win10.png" width="600">

