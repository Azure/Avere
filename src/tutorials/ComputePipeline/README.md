# Azure Compute Pipeline

This sample builds customized images from Azure platform images using the [Azure Image Builder](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-overview) service. It then deploys the custom images to [Azure Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/) and/or [Azure Virtual Machine Scale Sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview).

## Deployment Instructions

To run this sample, follow the deployment steps below. Since custom image building is a long-running process,
it is recommended to run the deployment orchestration script (either *Deploy.sh* or *Deploy.ps1*) locally.

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

5. Review and edit each of the following template parameter configuration files per your environment.
Ensure that `enabled: true` is set for each of the image and machine configurations to be deployed.

`Identity.Parameters.json`

`Images.Parameters.json`

`Machines.Parameters.json`

6. Review and edit the variables at the top of the deployment orchestration script file per your environment.

`Deploy.sh` OR `Deploy.ps1`

7. Execute the configured deployment orchestration script.
