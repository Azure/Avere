# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.3.1 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix,

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory\Deploy.psm1"

# 01 - Gallery
$computeRegionIndex = 0
$moduleName = "01 - Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\01-Gallery.json"
$templateParameters = "$templateDirectory\01-Gallery.Parameters.json"
$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
if (!$groupDeployment) { return }

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value
$imageGallery | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

Write-Output -InputObject $imageGallery -NoEnumerate
