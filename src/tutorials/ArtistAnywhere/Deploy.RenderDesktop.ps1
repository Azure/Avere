param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("WestUS2")
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

$networkOnly = $false
$sharedServices = New-SharedServices $resourceGroupNamePrefix $templateDirectory $networkOnly $computeRegionNames
$computeNetworks = $sharedServices.computeNetworks
$imageGallery = $sharedServices.imageGallery
$logAnalytics = $sharedServices.logAnalytics

# * - Render Desktop Image Job
$moduleName = "* - Render Desktop Image Job"
New-TraceMessage $moduleName $false
$renderDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $imageGallery
$renderDesktopImages = Receive-Job -InstanceId $renderDesktopImagesJob.InstanceId -Wait
if (!$renderDesktopImages) { return }
New-TraceMessage $moduleName $true

# * - Render Desktop Machines Job
$moduleName = "* - Render Desktop Machines Job"
New-TraceMessage $moduleName $false
$renderDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $renderManagers, $imageGallery, $logAnalytics
$renderDesktopMachines = Receive-Job -InstanceId $renderDesktopMachinesJob.InstanceId -Wait
if (!$renderDesktopMachines) { return }
New-TraceMessage $moduleName $true
