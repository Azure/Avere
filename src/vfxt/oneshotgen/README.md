# Marketplace Template

This folder builds the marketplace template.  It uses the python script `gen-arm-templates.py` to package up the installation script inside the customData of the template so that the template requires no external downloading to run.

Use Python 2.7 with this project.  

The script also creates a marketplace.zip file for upload to the marketplace and includes the following two files:
1. `mainTemplate.json` - the Azure Resource Manager Solution template that implements the one shot Avere vFXT deployment
2. `createUiDefinition.json` - this is the Wizard definition for the solution template.  It provides verification on the password and also provides drop downs for storage account and virtual networks.  To learn more about the user interface definition file visit https://docs.microsoft.com/en-us/azure/managed-applications/create-uidefinition-overview.