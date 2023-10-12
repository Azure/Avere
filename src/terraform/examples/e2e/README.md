# Azure Artist Anywhere (AAA) Solution Deployment Framework <img src=".github/images/Azure-A-24px.png" style="vertical-align:bottom" />

Azure Artist Anywhere (AAA) is a *modular & configurable [infrastructure-as-code](https://learn.microsoft.com/devops/deliver/what-is-infrastructure-as-code) solution deployment framework* for Azure HPC & AI [Rendering](https://azure.microsoft.com/solutions/high-performance-computing/rendering). Ignite remote artist creativity with Azure [global scale](https://azure.microsoft.com/global-infrastructure) and distributed computing innovation via [HPC-Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc) and [GPU-Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu) infrastructure.

The following design principles are implemented across each module of the Azure Artist Anywhere (AAA) solution deployment framework.
* Defense-in-depth layered security model across [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview), [Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) / [Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc
* Any custom or 3rd-party software (such as a render manager, render engines, etc) in a [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) custom image is supported
* Clean separation of AAA module deployment configuration files (***config.auto.tfvars***) and resource template files (****.tf***) via [Terraform](https://www.terraform.io)

| **Module Name** | **Module Description** | **Is Module Required<br>for Burst Render?<br>(*Compute Only*)** | **Is Module Required<br>for Full Solution?<br>(*Compute & Storage*)** |
| - | - | - | - |
| [0&#160;Global&#160;Foundation](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/0.Global.Foundation) | Defines&#160;global&#160;config&#160;([Azure&#160;region(s)](https://azure.microsoft.com/regions))&#160;and&#160;core&#160;solution resources ([Terraform state storage](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm), [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), etc). | Yes | Yes |
| [1 Virtual Network](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/1.Virtual.Network) | Deploys [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview), [Private DNS](https://learn.microsoft.com/azure/dns/private-dns-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc with [VPN](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) gateway services. | Yes,&#160;if&#160;[Virtual&#160;Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed | Yes,&#160;if&#160;[Virtual&#160;Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed |
| [2 Image Builder](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/2.Image.Builder) | Deploys [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) image definitions and templates<br />for building custom images via the [Image Builder](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) service. | No, use your custom images via [image.id](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L14) | No, use your custom images via [image.id](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L14) |
| [3 File Storage](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/3.File.Storage) | Deploys native ([Blob [NFS]](https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support), [Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction) or [NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)) or hosted ([Weka](https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) or [Hammerspace](https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5)) storage with optional sample scene data loaded for [PBRT](https://pbrt.org), [Blender](https://www.blender.org) and/or [MoonRay](https://openmoonray.org) rendering. | No | Yes |
| [4 File Cache](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/4.File.Cache) | Deploys [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) storage cluster for highly-available and scalable on-premises file caching on-demand. | Yes | No |
| [5 Render Manager](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/5.Render.Manager) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines) for render job management<br/>via any 3rd-party rendering job scheduling software. | No | No |
| [6 Render Farm](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/6.Render.Farm) | Deploys  [Virtual Machine Scale Sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) or [Batch](https://learn.microsoft.com/azure/batch/batch-technical-overview) for highly-scalable Linux and/or Windows render farm compute.<br/>Deploys [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/overview) ([DALL-E 2](https://openai.com/dall-e-2)) with [Semantic Kernel](https://learn.microsoft.com/semantic-kernel/overview/). | Yes, Azure OpenAI is *optional* config [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L515) | Yes, Azure OpenAI is *optional* config [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L515) |
| [7&#160;Artist&#160;Workstation](https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e/7.Artist.Workstation) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/overview) ([GPU Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu)) for [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview) and/or<br>[Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations with [HP Anyware](https://www.teradici.com). | No | No |

## Local Installation Dependencies

The following installation dependencies are required for local deployment orchestration.<br>
1. Make sure the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) is installed locally and accessible in your PATH environment variable.
1. Make sure the [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) is installed locally and accessible in your PATH environment variable.
1. Run `az login` locally to authenticate into your Azure account. This is how Terraform connects to Azure.
1. Run `az account show` to ensure your current Azure *subscription* context is set as expected. Verify the `id` property.<br>To change your current Azure subscription context, run `az account set --subscription <subscriptionId>`
1. Download this GitHub repository to your local workstation for module configuration and deployment orchestration.

## Module Configuration & Deployment

For each of the modules in the framework, here is the recommended deployment process.

1. Review and edit the config values in `config.auto.tfvars` for your target deployment.
   * For module `0 Global Foundation`,
       *  Review and edit the following config files.
           * `module/backend.config`
           * `module/variables.tf`
       * If Key Vault is enabled [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/0.Global.Foundation/module/variables.tf#L40), make sure the [Key Vault Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator) role is assigned to the current user via [Role-Based Access Control (RBAC)](https://learn.microsoft.com/azure/role-based-access-control/overview).
   * For modules `2 Image Builder`, `5 Render Manager`, `6 Render Farm` and `7 Artist Workstation`,
       * Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
       * By default, [Spot](https://learn.microsoft.com/azure/virtual-machines/spot-vms) is enabled in module `6 Render Farm` configuration. Therefore, Spot cores quota should be approved for your Azure subscription and target region(s).
   * For modules `5 Render Manager`, `6 Render Farm` and `7 Artist Workstation`, make sure the **image.id** config references the correct custom image in your Azure subscription [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries).
   * For modules `6 Render Farm` and `7 Artist Workstation`, make sure the **fileSystems** config has the correct values for your target storage environment.
1. For module `0 Global Foundation`, run `terraform init` to initialize the module local directory (append `-upgrade` if older providers are detected).
1. For all modules except `0 Global Foundation`, run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the module local directory (append `-upgrade` if older providers are detected).
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources).
1. Review the displayed Terraform deployment Plan *before* confirming to add, change and/or destroy Azure resources.
   * For module `2 Image Builder`, use the Azure portal or [Image Builder CLI](https://learn.microsoft.com/cli/azure/image/builder#az-image-builder-run) to start image build runs after image template deployment.

## Render Job Samples

The following sample images were [rendered on Azure](https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4) via multiple render farm, engine and job submission options.

### [Disney Moana Island](https://www.disneyanimation.com/resources/moana-island-scene)

The following Disney Moana Island scene was rendered on Azure via the [Physically-Based Ray Tracer (PBRT) v4](https://github.com/mmp/pbrt-v4) render engine.

<p align="center">
  <img src=".github/images/moana-island.png" />
</p>

To render the Disney Moana Island scene on an Azure **Linux** render farm, the following job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.

```deadlinecommand -SubmitCommandLineJob -name moana-island -executable pbrt -arguments "--outfile /mnt/content/pbrt/moana/island-v4.png /mnt/content/pbrt/moana/island/pbrt-v4/island.pbrt"```

To render the Disney Moana Island scene on an Azure **Windows** render farm, the following job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.

```deadlinecommand -SubmitCommandLineJob -name moana-island -executable pbrt.exe -arguments "--outfile H:\pbrt\moana\island-v4.png H:\pbrt\moana\island\pbrt-v4\island.pbrt"```

### [Blender Splash Screen](https://www.blender.org/download/demo-files/#splash)

The following Blender 3.4 Splash screen was rendered on Azure via the [Blender](https://www.blender.org) render engine.

<p align="center">
  <img src=".github/images/blender-splash-3.4.png" />
</p>

To render the Blender Splash screen on an Azure **Linux** render farm, the following job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender -arguments "--background /mnt/content/blender/3.4/splash.blend --render-output /mnt/content/blender/3.4/splash --enable-autoexec --render-frame 1"```

To render the Blender Splash screen on an Azure **Windows** render farm, the following job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender.exe -arguments "--background H:\blender\3.4\splash.blend --render-output H:\blender\3.4\splash --enable-autoexec --render-frame 1"```

https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4

If you have any questions or issues, please contact AzureArtistAnywhere@microsoft.com
