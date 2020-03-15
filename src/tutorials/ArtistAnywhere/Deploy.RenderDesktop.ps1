# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.2.0 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("West US 2", "East US 2"),

	# Set to true to deploy Azure Virtual Desktop (http://docs.microsoft.com/azure/virtual-desktop/overview)
	[boolean] $virtualDesktopDeploy = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory\Deploy.psm1"

$sharedServices = New-SharedServices $false
$computeNetworks = $sharedServices.computeNetworks
$imageGallery = $sharedServices.imageGallery
$logAnalytics = $sharedServices.logAnalytics

# * - Render Desktop Image Job
$moduleName = "* - Render Desktop Image Job"
New-TraceMessage $moduleName $true
$renderDesktopImageJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderDesktop.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $imageGallery
$renderDesktopImageId = Receive-Job -InstanceId $renderDesktopImageJob.InstanceId -Wait
if (!$renderDesktopImageId) { return }
New-TraceMessage $moduleName $false

# * - Render Desktop Machines Job
$moduleName = "* - Render Desktop Machines Job"
New-TraceMessage $moduleName $true
$renderDesktopMachinesJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $renderDesktopImageId, $renderManagers, $logAnalytics
$renderDesktopMachines = Receive-Job -InstanceId $renderDesktopMachinesJob.InstanceId -Wait
if (!$renderDesktopMachines) { return }
New-TraceMessage $moduleName $false

$moduleDirectory = "RenderDesktop"

# 12 - Virtual Desktop Pool
if ($virtualDesktopDeploy) {
	$moduleName = "12 - Virtual Desktop Pool"
	New-TraceMessage $moduleName $true
	for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
		New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
		$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Desktop"
		$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
		if (!$resourceGroup) { return }
	
		$templateResources = "$templateDirectory\$moduleDirectory\12-Desktop.Pool.json"
		$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\12-Desktop.Pool.Parameters.json" -Raw | ConvertFrom-Json).parameters

		$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
		$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
		if (!$groupDeployment) { return }
		New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
	}
	New-TraceMessage $moduleName $false
}
