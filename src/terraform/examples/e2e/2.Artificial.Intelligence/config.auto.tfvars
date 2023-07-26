resourceGroupName = "ArtistAnywhere.AI" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

##################################################################################
# Open AI (https://learn.microsoft.com/azure/cognitive-services/openai/overview) #
##################################################################################

openAI = {
  regionName    = "EastUS"
  accountName   = "zai"
  domainName    = "zai"
  serviceTier   = "S0"
  enableStorage = false
  networkAccess = {
    enablePublic     = true
    restrictOutbound = false
  }
  modelDeployments = [
    {
      name    = "gpt-35-turbo"
      format  = "OpenAI"
      version = "0613"
      scale   = "Standard"
    }
  ]
}

####################################################################
# Function App (https://learn.microsoft.com/azure/azure-functions) #
####################################################################

functionApp = {
  name = "zai"
  servicePlan = {
    computeTier = "S1"
    alwaysOn    = true
  }
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
