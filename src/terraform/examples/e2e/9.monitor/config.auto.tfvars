resourceGroupName = "AzureRender.Network.Monitor"

# Monitor - https://docs.microsoft.com/en-us/azure/azure-monitor/overview
monitorWorkspace = {
  name               = "AzRender"
  sku                = "PerGB2018"
  retentionDays      = 90
  publicIngestEnable = false
  publicQueryEnable  = false
}

# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
}
