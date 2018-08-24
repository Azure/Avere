# Windows 10 Avere vFXT Mounted Workstation

This 20 minute deployment will setup a Windows 10 Avere Workstation with various tools and features including:

1. **AvereVFXT Mounted Volume** - automatically mount the Avere VFXT volume to c:\AvereVFXT, and adds a shortcut to the Desktop

2. **Avere Admin Page on Desktop and Edge Home Button** - the desktop and Edge browser home button points to the Avere Management Endpoint

3. **Media Software** - The Window Media Service Pack, and VirtualDub enable post production of content including turning rendered frames into movies.

4. **Azure Batch Explorer** - Azure Batch Explorer enables easy management and viewing of batch jobs.

5. **Azure Storage Explorer** - Azure Storage Explorer allows management of all Azure Storage accounts.

This solution can be deployed through the portal or cloud shell.

## Portal Deployment

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fwin10vfxtmounted%2Fwin10-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Save the output values of the deployment for access to the Windows 10 Avere Workstation.

## Using the Windows 10 Avere Workstation

1. RDP to the clientAddress from the output parameters in the last command.

2. Once logged in, notice the following:
   1. Desktop Shortcuts for the Avere Management WebUI, Avere Mounted Volume, Batch Explorer, StorageExplorer, , and Virtual Dub
   2. Avere Mounted Volume is mounted to c:\AvereVFXT
   3. Avere vFXT Web UI - either opened by Desktop shortcut or "Home" button.

<img src="images/win10.png" width="600">

The source code to produce the template is located [here](../src/win10vfxtmounted).