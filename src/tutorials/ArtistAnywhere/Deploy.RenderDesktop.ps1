# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.3.1 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("West US 2", "East US 2")
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory\Deploy.psm1"

$sharedServices = New-SharedServices $false
$computeNetworks = $sharedServices.computeNetworks
$imageGallery = $sharedServices.imageGallery
$logAnalytics = $sharedServices.logAnalytics

# * - Render Desktop Image Job
$moduleName = "* - Render Desktop Image Job"
New-TraceMessage $moduleName $false
$renderDesktopImageJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderDesktop.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $imageGallery
$renderDesktopImages = Receive-Job -InstanceId $renderDesktopImageJob.InstanceId -Wait
if (!$renderDesktopImages) { return }
New-TraceMessage $moduleName $true

# * - Render Desktop Machines Job
$moduleName = "* - Render Desktop Machines Job"
New-TraceMessage $moduleName $false
$renderDesktopMachinesJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $renderManagers, $logAnalytics
$renderDesktopMachines = Receive-Job -InstanceId $renderDesktopMachinesJob.InstanceId -Wait
if (!$renderDesktopMachines) { return }
New-TraceMessage $moduleName $true
