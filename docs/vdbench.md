# Vdbench - measuring vFXT performance

This is a basic setup to generate small and medium sized workloads to test the vFXT memory and disk subsystems.

Suggested configuration is 12 x Standard_D2s_v3 clients for each group of 3 vFXT nodes.

[vdbench 5.04.07 documentation (PDF)](https://download.averesystems.com/software/vdbench-50407.pdf)

This solution can be deployed through the portal or cloud shell.

## Portal deployment

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button below:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fvdbench%2Fvdbench-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Save the output values of the deployment for access to the vdbench cluster.

> Note: The source code to produce the deploy template is located [here](../src/vdbench).

## Cloud shell deployment

1. To deploy vdbench, first open a cloud shell from http://portal.azure.com or https://shell.azure.com.

2. Run the following commands in cloud shell to deploy, updating the commented variables:

   ```bash
   # set the subscription, resource group, and location
   export DstSub=#"SUBSCRIPTION_ID"
   export DstResourceGroupName=#"example_vdbench_resourcegroup"
   export DstLocation=#"eastus2"
   
   mkdir vdbench
   cd vdbench

   # get the Avere vFXT controller template and edit parameters
   curl -o azuredeploy.json https://raw.githubusercontent.com/Azure/Avere/master/src/vdbench/vdbench-azuredeploy.json
   curl -o azuredeploy.parameters.json https://raw.githubusercontent.com/Azure/Avere/master/src/vdbench/vdbench-azuredeploy.parameters.json
   vi azuredeploy.parameters.json
   
   # deploy the template
   az account set --subscription $DstSub
   az group create --name $DstResourceGroupName --location $DstLocation
   az group deployment create --resource-group $DstResourceGroupName --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
   ```

4. Scroll up in the deployment output to the section labeled "outputs".

## Using vdbench

1. After deployment is complete, log in using the SSH command found in the "outputs" list and run the following commands to set your private SSH secret:

   ```bash
   touch ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   vi ~/.ssh/id_rsa
   ```
	
2. Run `./copy_idrsa.sh` to copy your private key to all nodes, and to add all nodes to the "known hosts" list. (**Note** if your ssh key requires a passphrase, some extra steps are needed to make this work. Consider creating a key that does not require a passphrase for ease of use.)


### Memory test 

1. To run the memory test (approximately 20 minutes), issue the following command:

   ```bash
   cd
   ./run_vdbench.sh inmem.conf uniquestring1
   ```

2. Log in to the Avere vFXT cluster GUI (Avere Control Panel - instructions [here](access_cluster.md)) to watch the performance metrics. You will see a similar performance chart to the following:

   <img src="images/vdbench_inmem.png">

### On-disk test

1. To run the on-disk test (approximately 40 minutes) issue the following command:

   ```bash
   cd
   ./run_vdbench.sh ondisk.conf uniquestring2
   ```

2. Log in to the Avere Control Panel ([instructions](access_cluster.md)) to watch the performance metrics. You will see a performance chart similar to the following one:

   <img src="images/vdbench_ondisk.png">

