# Windows With Terraform

Here are the steps to setup a Windows environment:
1. Download Terraform from https://releases.hashicorp.com/terraform/0.15.0/terraform_0.15.0_windows_amd64.zip and install to a path

1. Install az cli per [az cli install instructions for Windows](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli)

1. Save the latest Avere provider from [releases](https://github.com/Azure/Avere/releases) to `%APPDATA%\terraform.d\plugins\registry.terraform.io\hashicorp\avere`.  For example, version 1.0.0 will be save to path `%APPDATA%\terraform.d\plugins\registry.terraform.io\hashicorp\avere\1.0.0\windows_amd64\terraform-provider-avere_v1.0.0.exe`.  Here is the powershell to automatically download to the correct versioned directory:

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