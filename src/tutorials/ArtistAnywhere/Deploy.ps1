# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.0.76 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for new Azure resource groups created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Artist.Anywhere",

	# Set to an Azure region location for compute (http://azure.microsoft.com/global-infrastructure/locations)
	[string] $regionLocationCompute = "West US 2",

	# Set to "" to skip Azure storage deployment (e.g., if you are connected to an on-premises storage system)
	[string] $regionLocationStorage = "West US 2",

	# Set to a root directory for deployment of the render farm manager and worker services
	[string] $serviceRootDirectory = "/home/az/",

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageDeployNetApp = $false,

	# Set to true to deploy Azure Blob Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageDeployBlob = $false,

	# Set to true to deploy Azure Virtual Machines with a render farm manager client app for render job submission
	[boolean] $clientDeploy = $false
)

$templateRootDirectory = $PSScriptRoot
$imageBuilderServiceId = "cf32a0cc-373c-47c9-9156-0db11f6a6dfc"
$imageTemplateResourceType = "Microsoft.VirtualMachineImages/imageTemplates"

Import-Module "$templateRootDirectory\Deploy.psm1"

# 0 - Network
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (0 - Network Deployment Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Network"
$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
if (!$resourceGroup) { return }

$templateResources = "$templateRootDirectory\0-Network.json"
$templateParameters = "$templateRootDirectory\0-Network.Parameters.json"
$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$computeNetworkResourceGroupName = $resourceGroupName
$computeNetworkName = $groupDeployment.properties.outputs.virtualNetworkName.value
$privateDomainName = $groupDeployment.properties.outputs.virtualNetworkPrivateDomainName.value
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (0 - Network Deployment End)")

# 1 - Gallery
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (1 - Gallery Deployment Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
if (!$resourceGroup) { return }

$templateResources = "$templateRootDirectory\1-Gallery.json"
$templateParameters = "$templateRootDirectory\1-Gallery.Parameters.json"
$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$imageGalleryResourceGroupName = $resourceGroupName
$imageGalleryName = $groupDeployment.properties.outputs.imageGalleryName.value
$imageDefinitions = $groupDeployment.properties.outputs.imageDefinitions.value
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (1 - Gallery Deployment End)")

# * - Background Jobs Start
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (* - Background Jobs Start)")
$imageDefinition = Get-ImageDefinition "Render" $imageDefinitions
$storageCacheJob = Start-Job -FilePath "$templateRootDirectory\Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $regionLocationCompute, $regionLocationStorage, $storageDeployNetApp, $storageDeployBlob, $computeNetworkResourceGroupName, $computeNetworkName, $privateDomainName
$renderManagersJob = Start-Job -FilePath "$templateRootDirectory\Deploy.RenderManagers.ps1" -ArgumentList $resourceGroupNamePrefix, $regionLocationCompute, $serviceRootDirectory, $imageGalleryResourceGroupName, $imageGalleryName, $imageDefinition, $computeNetworkResourceGroupName, $computeNetworkName

# 7 - Worker Image Template
$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
$imageTemplateName = "RenderWorker"
$imageTemplate = (az resource list --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName) | ConvertFrom-Json
if ($imageTemplate.length -eq 0) {
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (7 - Worker Image Template Deployment Start)")
	$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
	if (!$resourceGroup) { return }

	$roleAssignment = az role assignment create --resource-group $resourceGroupName --role Contributor --assignee $imageBuilderServiceId
	if (!$roleAssignment) { return }

	$templateResources = "$templateRootDirectory\7-Worker.Image.json"
	$templateParameters = (Get-Content "$templateRootDirectory\7-Worker.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters

	$templateParameters.renderWorker.value | Add-Member -MemberType NoteProperty -Name "rootDirectory" -Value $serviceRootDirectory
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
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (7 - Worker Image Template Deployment End)")
}

# 7.1 - Worker Image Version
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (7.1 - Worker Image Version Build Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
$imageVersion = Get-ImageVersion $resourceGroupName $imageGalleryName $imageDefinition.name $imageTemplateName
if (!$imageVersion) {
	$imageVersion = (az resource invoke-action --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName --action Run) | ConvertFrom-Json
	if (!$imageVersion) { return }
	$imageVersion = Get-ImageVersion $resourceGroupName $imageGalleryName $imageDefinition.name $imageTemplateName
}
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (7.1 - Worker Image Version Build End)")

# * - Background Jobs End
$storageMounts = ""
$jobOutput = Receive-Job -InstanceId $storageCacheJob.InstanceId -Wait
if ($jobOutput) {
	$storageMounts = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jobOutput.ToString()))
}
$jobOutput = Receive-Job -InstanceId $renderManagersJob.InstanceId -Wait
if (!$jobOutput) { return }
$renderManager = $jobOutput.ToString()
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (* - Background Jobs End)")

# 8 - Worker Machines
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (8 - Worker Machines Deployment Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Worker"
$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
if (!$resourceGroup) { return }

$templateResources = "$templateRootDirectory\8-Worker.Machines.json"
$templateParameters = (Get-Content "$templateRootDirectory\8-Worker.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
$machineExtensionScript = Get-MachineExtensionScript "8-Worker.Machines.sh"

$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $serviceRootDirectory
$templateParameters | Add-Member -MemberType NoteProperty -Name "rootDirectory" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $storageMounts
$templateParameters | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $templateParameter
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $renderManager
$templateParameters | Add-Member -MemberType NoteProperty -Name "renderManager" -Value $templateParameter
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
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (8 - Worker Machines Deployment End)")

if ($clientDeploy) {
	# 9 - Client Image Template
	$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
	$imageTemplateName = "RenderClient"
	$imageTemplate = (az resource list --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName) | ConvertFrom-Json
	if ($imageTemplate.length -eq 0) {
		Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (9 - Client Image Template Deployment Start)")
		$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
		if (!$resourceGroup) { return }

		$roleAssignment = az role assignment create --resource-group $resourceGroupName --role Contributor --assignee $imageBuilderServiceId
		if (!$roleAssignment) { return }

		$templateResources = "$templateRootDirectory\9-Client.Image.json"
		$templateParameters = (Get-Content "$templateRootDirectory\9-Client.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters

		$templateParameters.renderClient.value | Add-Member -MemberType NoteProperty -Name "rootDirectory" -Value $serviceRootDirectory
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
		Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (9 - Client Image Template Deployment End)")
	}

	# 9.1 - Client Image Version
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (9.1 - Client Image Version Build Start)")
	$resourceGroupName = "$resourceGroupNamePrefix-Gallery"
	$imageVersion = Get-ImageVersion $resourceGroupName $imageGalleryName $imageDefinition.name $imageTemplateName
	if (!$imageVersion) {
		$imageVersion = (az resource invoke-action --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName --action Run) | ConvertFrom-Json
		if (!$imageVersion) { return }
		$imageVersion = Get-ImageVersion $resourceGroupName $imageGalleryName $imageDefinition.name $imageTemplateName
	}
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (9.1 - Client Image Version Build End)")

	# 10 - Client Machines
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (10 - Client Machines Deployment Start)")
	$resourceGroupName = "$resourceGroupNamePrefix-Client"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
	if (!$resourceGroup) { return }

	$templateResources = "$templateRootDirectory\10-Client.Machines.json"
	$templateParameters = (Get-Content "$templateRootDirectory\10-Client.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$machineExtensionScript = Get-MachineExtensionScript "8-Worker.Machines.sh"

	$templateParameter = New-Object PSObject
	$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $serviceRootDirectory
	$templateParameters | Add-Member -MemberType NoteProperty -Name "rootDirectory" -Value $templateParameter
	$templateParameter = New-Object PSObject
	$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $storageMounts
	$templateParameters | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $templateParameter
	$templateParameter = New-Object PSObject
	$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $renderManager
	$templateParameters | Add-Member -MemberType NoteProperty -Name "renderManager" -Value $templateParameter
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
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (10 - Client Machines Deployment End)")
}