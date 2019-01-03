# Source for Marketplace and Solution Template Artifacts

This folder contains the source to produce the following files:
 1. `marketplace.zip` - the zip file to be submitted to marketplace and contains the marketplace wizard definition and oneshot template:
     1. `mainTemplate.json` - the Azure Resource Manager Solution template that implements the one shot Avere vFXT deployment
     2. `createUiDefinition.json` - this is the Wizard definition for the solution template.  It provides verification on the password and also provides drop downs for storage account and virtual networks.  To learn more about the user interface definition file visit https://docs.microsoft.com/en-us/azure/managed-applications/create-uidefinition-overview.
 1. `../azuredeploy-auto.json` - the oneshot template for customers who want to automate their deployment.

To produce the artifacts run python 2.7 script `gen-arm-templates.py` to create the artifacts.  The python script embeds the `installvfxt.sh` as customData (cloudinit) inside the virtual machine definition.