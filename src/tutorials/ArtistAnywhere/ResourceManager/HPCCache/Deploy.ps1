param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS"         # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $hpcCache = @{                      # https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview
        "name" = ""
        "size" = 3072                   # 3072, 6144, 12288, 24576, 49152
        "throughput" = "Standard_2G"    # Standard_2G, Standard_4G, Standard_8G
        "mtuSize" = 1500                # https://docs.microsoft.com/azure/hpc-cache/configuration#adjust-mtu-value
    },
    $storageTargets = @(                # https://docs.microsoft.com/azure/hpc-cache/hpc-cache-add-storage
        # @{
        #     "name" = ""
        #     "type" = "nfs3"
        #     "resourceGroupName" = ""
        #     "accountName" = ""
        #     "host" = ""
        #     "usageModel" = "WRITE_AROUND"
        #     "junctions" = @(
        #         @{
        #             "namespacePath" = "/"
        #             "nfsExport" = "/"
        #             "targetPath" = "/"
        #         }
        #     )
        # }
    ),
    $virtualNetwork = @{                # https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = $resourceGroup.name
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

foreach ($storageTarget in $storageTargets) {
    $storageType = $storageTarget.type.ToLower()
    if ($storageType -eq "adls") {
        $principalType = "ServicePrincipal"
        $principalId = "831d4223-7a3c-4121-a445-1e423591e57b" # Azure HPC Cache Resource Provider

        $storageId = az storage account show --resource-group $storageTarget.resourceGroupName --name $storageTarget.accountName --query "id" --output "tsv"

        $roleId = "17d1049b-9a84-46fb-8f53-869881c3d3ab" # Storage Account Contributor
        az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --scope $storageId

        $roleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Blob Data Contributor
        az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --scope $storageId
    }
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.hpcCache.value = $hpcCache
$templateConfig.parameters.storageTargets.value = $storageTargets
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
