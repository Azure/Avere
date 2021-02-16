function Get-BaseFramework ($rootDirectory, $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy) {
    $moduleDirectory = "BaseFramework"

    # (01) Virtual Network
    $moduleName = "(01) Virtual Network"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Network"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/01-VirtualNetwork.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/01-VirtualNetwork.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageNetwork.value.regionName = $storageRegionName
    $templateConfig.parameters.computeNetwork.value.regionName = $computeRegionName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageNetwork = $groupDeployment.properties.outputs.storageNetwork.value
    $computeNetwork = $groupDeployment.properties.outputs.computeNetwork.value
    $networkDomain = $groupDeployment.properties.outputs.networkDomain.value
    New-TraceMessage $moduleName $true

    # (02) Active Directory
    $moduleName = "(02) Active Directory"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/02-ActiveDirectory.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/02-ActiveDirectory.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $activeDirectory = $groupDeployment.properties.outputs.activeDirectory.value
    New-TraceMessage $moduleName $true

    # (03) Managed Identity
    $moduleName = "(03) Managed Identity"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/03-ManagedIdentity.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/03-ManagedIdentity.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $managedIdentity = $groupDeployment.properties.outputs.managedIdentity.value
    New-TraceMessage $moduleName $true

    # (04) Key Vault
    $moduleName = "(04) Key Vault"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/04-KeyVault.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/04-KeyVault.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $keyVault = $groupDeployment.properties.outputs.keyVault.value
    New-TraceMessage $moduleName $true

    Set-RoleAssignments "Key Vault" $null $computeNetwork $managedIdentity $keyVault

    # (05) Network Gateway
    if ($networkGatewayDeploy) {
        $moduleName = "(05) Network Gateway"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Network"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/05-NetworkGateway.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/05-NetworkGateway.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.storageNetwork.value = $storageNetwork
        $templateConfig.parameters.computeNetwork.value = $computeNetwork
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        New-TraceMessage $moduleName $true
    }

    # (06) Monitor Insight
    $moduleName = "(06) Monitor Insight"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/06-MonitorInsight.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/06-MonitorInsight.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
    $appInsights = $groupDeployment.properties.outputs.appInsights.value
    New-TraceMessage $moduleName $true

    # (07) Image Gallery
    $moduleName = "(07) Image Gallery"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Gallery"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/07-ImageGallery.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/07-ImageGallery.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $imageGallery = $groupDeployment.properties.outputs.imageGallery.value
    New-TraceMessage $moduleName $true

    Set-RoleAssignments "Image Builder" $null $computeNetwork $managedIdentity $keyVault $imageGallery

    # (08) Container Registry
    $moduleName = "(08) Container Registry"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Registry"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/08-ContainerRegistry.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/08-ContainerRegistry.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $containerRegistry = $groupDeployment.properties.outputs.containerRegistry.value
    New-TraceMessage $moduleName $true

    $baseFramework = New-Object PSObject
    $baseFramework | Add-Member -MemberType NoteProperty -Name "storageNetwork" -Value $storageNetwork
    $baseFramework | Add-Member -MemberType NoteProperty -Name "computeNetwork" -Value $computeNetwork
    $baseFramework | Add-Member -MemberType NoteProperty -Name "networkDomain" -Value $networkDomain
    $baseFramework | Add-Member -MemberType NoteProperty -Name "activeDirectory" -Value $activeDirectory
    $baseFramework | Add-Member -MemberType NoteProperty -Name "managedIdentity" -Value $managedIdentity
    $baseFramework | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
    $baseFramework | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
    $baseFramework | Add-Member -MemberType NoteProperty -Name "appInsights" -Value $appInsights
    $baseFramework | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
    $baseFramework | Add-Member -MemberType NoteProperty -Name "containerRegistry" -Value $containerRegistry
    return $baseFramework
}
