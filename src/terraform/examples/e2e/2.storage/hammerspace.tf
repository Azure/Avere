#######################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#######################################################################################################

variable "hammerspace" {
  type = object(
    {
      clusterName = string
    }
  )
}
