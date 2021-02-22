param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $virtualNetwork = @{            # https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview
        "name" = "MediaPipeline"
        "addressSpace" = "10.0.0.0/22"
        "subnets" = @(
            @{
                "name" = "Compute"
                "properties" = @{
                    "addressPrefix" = "10.0.0.0/24"
                }
            }
            @{
                "name" = "Storage"
                "properties" = @{
                    "addressPrefix" = "10.0.1.0/24"
                    "serviceEndpoints" = @(
                        @{
                            "service" = "Microsoft.Storage"
                        }
                    )
                }
            }
            @{
                "name" = "NetAppFiles"
                "properties" = @{
                    "addressPrefix" = "10.0.2.0/24"
                    "delegations" = @(
                        @{
                            "name" = "NetAppVolumes"
                            "properties" = @{
                              "serviceName" = "Microsoft.NetApp/volumes"
                            }
                        }
                    )
                }
            }
            @{
                "name" = "GatewaySubnet"
                "properties" = @{
                    "addressPrefix" = "10.0.3.0/24"
                }
            }
        )
    },
    $virtualNetworkGateway = @{     # https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
        "name" = ""
        "type" = "Vpn"
        "vpnGeneration" = "Generation2"
        "vpnTier" = "VpnGw2"
        "vpnType" = "RouteBased"
        "publicAddress" = @{
            "type" = "Basic"
            "allocationMethod" = "Dynamic"
        }
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig.parameters.virtualNetworkGateway.value = $virtualNetworkGateway
$templateConfig | ConvertTo-Json -Depth 8 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
