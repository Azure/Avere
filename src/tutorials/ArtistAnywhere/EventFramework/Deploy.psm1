function Get-EventFramework ($rootDirectory, $baseFramework, $resourceGroupNamePrefix, $computeRegionName) {
    $computeNetwork = $baseFramework.computeNetwork
    $managedIdentity = $baseFramework.managedIdentity

    $moduleDirectory = "EventFramework"

    # (09) Event Grid
    $moduleName = "(09) Event Grid"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/09-EventGrid.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/09-EventGrid.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.storageAccount.value.queueName = $storageAccount.queueName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true

    # (10) Function App
    $moduleName = "(10) Function App"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/10-FunctionApp.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/10-FunctionApp.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true

    $eventFramework = New-Object PSObject
    $eventFramework | Add-Member -MemberType NoteProperty -Name "eventGrid" -Value $eventGrid
    $eventFramework | Add-Member -MemberType NoteProperty -Name "functionApp" -Value $functionApp
    return $eventFramework
}
