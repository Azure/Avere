resourceGroupName = "ArtistAnywhere.AI" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

##################################################################################
# Open AI (https://learn.microsoft.com/azure/cognitive-services/openai/overview) #
##################################################################################

openAI = {
  regionName  = "EastUS"
  accountName = "azstudio"
  domainName  = "azstudio"
  serviceTier = "S0"
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
