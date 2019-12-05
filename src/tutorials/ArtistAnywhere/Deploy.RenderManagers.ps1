# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.0.76 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for new Azure resource groups created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Artist.Anywhere",

	# Set to an Azure region location for compute (http://azure.microsoft.com/global-infrastructure/locations)
	[string] $regionLocationCompute = "West US 2",

	# Set to a root directory for deployment of the render farm manager and worker services
	[string] $serviceRootDirectory = "/home/az/",

	# Set to the Azure resource group name for the Azure Shared Image Gallery resources
	[string] $imageGalleryResourceGroupName,

	# Set to the Azure resource name for the Azure Shared Image Gallery resource
	[string] $imageGalleryName,

	# Set to the Azure image definition in the Azure Shared Image Gallery
	[object] $imageDefinition,

	# Set to the Azure resource group name for the Azure Networking resources for compute
	[string] $computeNetworkResourceGroupName,

	# Set to the Azure resource name for the Azure Virtual Network resource for compute
	[string] $computeNetworkName
)

$templateRootDirectory = $PSScriptRoot
if (!$templateRootDirectory) {
	$templateRootDirectory = $using:templateRootDirectory
}
$imageBuilderServiceId = $using:imageBuilderServiceId
$imageTemplateResourceType = $using:imageTemplateResourceType

Import-Module "$templateRootDirectory\Deploy.psm1"
$templateRootDirectory = $templateRootDirectory + "\RenderManagers"

# 4 - Manager Data
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (4 - Manager Data Deployment Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Manager"
$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
if (!$resourceGroup) { return }

$templateResources = "$templateRootDirectory\4-Manager.Data.json"
$templateParameters = (Get-Content "$templateRootDirectory\4-Manager.Data.Parameters.json" -Raw | ConvertFrom-Json).parameters

$dataServerExists = $false
$dataServerName = $templateParameters.renderManager.value.dataServerName.ToLower()
$dataServers = (az postgres server list --resource-group $resourceGroupName) | ConvertFrom-Json -AsHashTable
foreach ($dataServer in $dataServers) {
	if ($dataServer.name -eq $dataServerName) {
		$dataServerExists = $true
	}
}

$databaseExists = $false
if ($dataServerExists) {
	$databaseName = $templateParameters.renderManager.value.databaseName
	$databases = (az postgres db list --resource-group $resourceGroupName --server-name $dataServerName) | ConvertFrom-Json
	foreach ($database in $databases) {
		if ($database.name -eq $databaseName) {
			$databaseExists = $true
		}
	}
}

$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $computeNetworkResourceGroupName
$templateParameters | Add-Member -MemberType NoteProperty -Name "virtualNetworkResourceGroupName" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $computeNetworkName
$templateParameters | Add-Member -MemberType NoteProperty -Name "virtualNetworkName" -Value $templateParameter
$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$managerDatabaseAdminSql = $groupDeployment.properties.outputs.managerDatabaseAdminSql.value
$managerDatabaseEndpoint = $groupDeployment.properties.outputs.managerDatabaseEndpoint.value
$managerDatabaseUsername = $groupDeployment.properties.outputs.managerDatabaseUsername.value
$managerDatabasePassword = $groupDeployment.properties.outputs.managerDatabasePassword.value
if ($databaseExists) { $managerDatabaseAdminSql = "" }
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (4 - Manager Data Deployment End)")

# 5 - Manager Image Template
$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
$imageTemplateName = "RenderManager"
$imageTemplate = (az resource list --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName) | ConvertFrom-Json
if ($imageTemplate.length -eq 0) {
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (5 - Manager Image Template Deployment Start)")
	$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
	if (!$resourceGroup) { return }

	$roleAssignment = az role assignment create --resource-group $resourceGroupName --role Contributor --assignee $imageBuilderServiceId
	if (!$roleAssignment) { return }

	$templateResources = "$templateRootDirectory\5-Manager.Image.json"
	$templateParameters = (Get-Content "$templateRootDirectory\5-Manager.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters

	$templateParameters.renderManager.value | Add-Member -MemberType NoteProperty -Name "rootDirectory" -Value $serviceRootDirectory
	if ($templateParameters.renderManager.value.databaseEndpoint -eq "") {
		$templateParameters.renderManager.value.databaseEndpoint = $managerDatabaseEndpoint
	}
	if ($templateParameters.renderManager.value.databaseUsername -eq "") {
		$templateParameters.renderManager.value.databaseUsername = $managerDatabaseUsername
	}
	if ($templateParameters.renderManager.value.databasePassword -eq "") {
		$templateParameters.renderManager.value.databasePassword = $managerDatabasePassword
	}
	$templateParameter = New-Object PSObject
	$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $imageGalleryName
	$templateParameters | Add-Member -MemberType NoteProperty -Name "imageGalleryName" -Value $templateParameter
	$templateParameter = New-Object PSObject
	$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $imageDefinition
	$templateParameters | Add-Member -MemberType NoteProperty -Name "imageDefinition" -Value $templateParameter
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
	$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$imageTemplateName = $groupDeployment.properties.outputs.imageTemplateName.value
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (5 - Manager Image Template Deployment End)")
}

# 5.1 - Manager Image Version
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (5.1 - Manager Image Version Build Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
$imageVersion = Get-ImageVersion $resourceGroupName $imageGalleryName $imageDefinition.name $imageTemplateName
if (!$imageVersion) {
	$imageVersion = (az resource invoke-action --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName --action Run) | ConvertFrom-Json
	if (!$imageVersion) { return }
	$imageVersion = Get-ImageVersion $resourceGroupName $imageGalleryName $imageDefinition.name $imageTemplateName
}
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (5.1 - Manager Image Version Build End)")

# 6 - Manager Machines
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (6 - Manager Machines Deployment Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Manager"
$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
if (!$resourceGroup) { return }

$templateResources = "$templateRootDirectory\6-Manager.Machines.json"
$templateParameters = (Get-Content "$templateRootDirectory\6-Manager.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
$machineExtensionScript = Get-MachineExtensionScript "6-Manager.Machines.sh"

$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $serviceRootDirectory
$templateParameters | Add-Member -MemberType NoteProperty -Name "rootDirectory" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $managerDatabaseAdminSql
$templateParameters | Add-Member -MemberType NoteProperty -Name "databaseAdminSql" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $imageVersion.id
$templateParameters | Add-Member -MemberType NoteProperty -Name "imageVersionId" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $machineExtensionScript
$templateParameters | Add-Member -MemberType NoteProperty -Name "machineExtensionScript" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $computeNetworkResourceGroupName
$templateParameters | Add-Member -MemberType NoteProperty -Name "virtualNetworkResourceGroupName" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $computeNetworkName
$templateParameters | Add-Member -MemberType NoteProperty -Name "virtualNetworkName" -Value $templateParameter
$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 3).Replace('"', '\"')
$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$renderManager = $groupDeployment.properties.outputs.renderManager.value
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (6 - Manager Machines Deployment End)")

Write-Output -InputObject $renderManager