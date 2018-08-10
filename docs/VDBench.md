# VDBench - measuring vFXT Performance

This is a basic setup to generate small and medium sized workloads to test the vFXT memory and disk subsystems.
Suggested config is 12 x Standard_D2s_v3 clients for each group of 3 vFXT nodes.
 
The vdbench documentation: <a href="https://download.averesystems.com/software/vdbench-50407.pdf" target="_blank">https://download.averesystems.com/software/vdbench-50407.pdf</a>.

This solution can be deployed through the portal or cloud shell.

## Portal Deployment

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fvdbench%2Fvdbench-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fvdbench%2Fvdbench-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png"/>
</a>

Save the output values of the deployment for access to the vdbench cluster.

## Cloud Shell Deployment

1. To deploy vdbench, first open a cloud shell from the [portal](http://portal.azure.com) or [cloud shell](https://shell.azure.com/).

2. Run the following commands in cloud shell to deploy, updating the commented variables:

```bash
# set the subscription, resource group, and location
export DstSub=#"SUBSCRIPTION_ID"
export DstResourceGroupName=#"example_vdbench_resourcegroup"
export DstLocation=#"eastus2"

mkdir vdbench
cd vdbench

# get the Avere vFXT controller template and edit parameters
curl -o azuredeploy.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vdbench/vdbench-azuredeploy.json
curl -o azuredeploy.parameters.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vdbench/vdbench-azuredeploy.parameters.json
vi azuredeploy.parameters.json

# deploy the template
az account set --subscription $DstSub
az group create --name $DstResourceGroupName --location $DstLocation
az group deployment create --resource-group $DstResourceGroupName --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
```

4. Scroll-up in the deployment output to a section labelled `"outputs"`.

## Using VDbench

1. Once Deployed, login using the SSH command found in the `"outputs"`` and run the following commands to set your private ssh secret:
```bash
touch ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
vi ~/.ssh/id_rsa
```
	
2. Run `./copy_idrsa.sh` to copy your private key to all nodes, and to add all nodes to the "known hosts" list (**note** if your ssh key requires a passphrase, some extra steps are needed to make this work, consider creating a key that does not require a passphrase for ease of use).

3. To run the approximately 20 minute memory test run the following command:

```bash
cd
./run_vdbench.sh inmem.conf uniquestring1
```

4. When you login to the Avere cluster (using instructions from [here](UsingThevFXT.md#explore-the-avere-vfxt-web-ui) Watch the metrics and explore the Avere vFXT Web UI), you will see a similar performance chart to the following chart:

<img src="images/vdbench_inmem.png">

5. To run the approximately 40 minute ondisk test run the following command:

```bash
cd
./run_vdbench.sh ondisk.conf uniquestring2
```

6. When you login to the Avere cluster (using instructions from [here](UsingThevFXT.md#explore-the-avere-vfxt-web-ui) Watch the metrics and explore the Avere vFXT Web UI), you will see a similar performance chart to the following chart:

<img src="images/vdbench_ondisk.png">

The source code to produce the template is located [here](../src/vdbench).