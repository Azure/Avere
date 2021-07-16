# Provider Pre-requisites

1. double check your Avere vFXT prerequisites, including running `az vm image terms accept --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

2. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
    * For Linux: 
    ```bash
    version=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name | sed -e 's/[^0-9]*\([0-9].*\)$/\1/')
    browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "terraform-provider-avere$")
    mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
    wget -O ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version $browser_download_url
    chmod 755 ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version
    ```

    * For Windows:
    ```Powershell
    # make Invoke-WebRequest go fast: https://stackoverflow.com/questions/14202054/why-is-this-powershell-code-invoke-webrequest-getelementsbytagname-so-incred
    $ProgressPreference = "SilentlyContinue"
    
    # get the latest download URL
    $latestPage         = Invoke-WebRequest https://api.github.com/repos/Azure/Avere/releases/latest
    ($latestpage.Content|ConvertFrom-Json|Select tag_name).tag_name -match '[^0-9]*([0-9\.].*)$'
    $version            = $matches[1]
    $browserDownloadUrl = (($latestpage.Content |ConvertFrom-Json|Select assets).assets |where-object {$_.browser_download_url -match ".exe"}).browser_download_url
    
    # download the provider
    $pluginsDirectory   = "$Env:APPDATA\terraform.d\plugins\registry.terraform.io\hashicorp\avere\$version\windows_amd64"
    md $pluginsDirectory -ea 0
    $pluginPath         = "$pluginsDirectory\terraform-provider-avere_v$version.exe"
    Write-Output "Downloading the avere plugin to $pluginPath"
    Invoke-WebRequest -OutFile $pluginPath $browserDownloadUrl
    ```
    

3. Review the [storage cache pre-reqs](../../examples/storagecache-rendering#pre-requisites)

## Upgrade

If you have downloaded a new provider to an existing project using the steps above, run `terraform init -upgrade` to pull in the new provider.

## Devops Pipeline

If you are building a DevOps pipeline, please see our pipeline page to learn how to [prepare a pipeline in multiple environments](../../examples/vfxt/pipeline).