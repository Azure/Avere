param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2" # https://azure.microsoft.com/global-infrastructure/geographies/
    },

    $hpcCache = @{
        "name" = ""
        "size" = 3072                # 3072, 6144, 12288, 24576, 49152
        "throughput" = "Standard_2G" # Standard_2G, Standard_4G, Standard_8G
        "mtuSize" = 1500             # https://docs.microsoft.com/azure/hpc-cache/configuration#adjust-mtu-value
    },

    $storageTargets = @(
        # @{
        #     "name" = "Azure-NetApp-Files"
        #     "type" = "nfs3"
        #     "host" = "10.0.1.4"
        #     "usageModel" = "WRITE_AROUND"
        #     "junctions" = @(
        #         @{
        #             "namespacePath" = "/mnt/cache/netapp"
        #             "nfsExport" = "/volume-a"
        #             "targetPath" = "/"
        #         }
        #     )
        # }
    ),

    $virtualNetwork = @{
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = ""
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.hpcCache.value = $hpcCache
$templateConfig.parameters.storageTargets.value = $storageTargets
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
