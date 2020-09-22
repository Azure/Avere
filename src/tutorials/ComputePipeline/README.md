# Azure Compute Pipeline

This sample builds customized images from Azure platform images and deploys them to Azure Virtual Machines and/or Virtual Machine Scale Sets.

## Deployment Instructions

To run this sample, execute the following deployment instructions. Since custom image building is a long-running process,
it is recommended to run the sample deployment orchestration script (either *Deploy.sh* or *Deploy.ps1*) locally.

However, you can use your own local environment instead with the Azure Command-Line Interface (CLI) installed.

1. Ensure the Azure Command-Line Interface (CLI) is installed locally via https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

2. Set your Azure subscription context by running the `az login` command locally.

3. Download the sample source files
```
mkdir az
cd az
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/tutorials/*" >> .git/info/sparse-checkout
git pull origin main
```

4. `cd src/tutorials/ComputePipeline`

5. Review and edit the following parameter configuration files per your environment. In the Images and Machines configuration files,
ensure that the `enabled: true` properties are set for each of the images and machines to be deployed.

`ComputePipeline.Identity.parameters.json`

`ComputePipeline.Images.parameters.json`

`ComputePipeline.Machines.parameters.json`

6. Review and edit the variables at the top of the deployment orchestration script file per your environment.

`Deploy.sh` OR `Deploy.ps1`

7. Execute the configured deployment orchestration script.
