# Azure Compute Pipeline

This sample builds customized images from Azure platform images and deploys them to Azure Virtual Machines and/or Virtual Machine Scale Sets.

## Deployment Instructions

To run this sample, execute the following deployment instructions. This process assumes use of Azure Cloud Shell.
However, you can use your own local environment instead with the Azure Command-Line Interface (CLI) installed.

1. Browse to https://shell.azure.com

2. Select either Bash or PowerShell in the upper-left dropdown per your deployment script preference.

3. Specify your Azure subscription by running this command with YOUR_SUBSCRIPTION_ID: ```az account set --subscription YOUR_SUBSCRIPTION_ID```.

4. Get the sample files
```bash
mkdir src
cd src
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/tutorials/*" >> .git/info/sparse-checkout
git pull origin main
```

5. `cd src/tutorials/ComputePipeline`

6. Review and edit the following parameter configuration files per your environment. In the Images and Machines configuration files, ensure that the 
`enabled: true` properties are set for each of the images and machines to be deployed.

`ComputePipeline.Identity.parameters.json`

`ComputePipeline.Images.parameters.json`

`ComputePipeline.Machines.parameters.json`

7. Review and edit the variables at the top of the deployment orchestration script file per your environment.

`Deploy.sh` OR `Deploy.ps1`

8. Execute the configured deployment orchestration script.
