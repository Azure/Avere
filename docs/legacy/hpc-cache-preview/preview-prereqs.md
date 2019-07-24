# Additional prerequisites for Azure HPC Cache private preview

These additional prerequisites apply to the private preview release. 

**Region** 

Private preview is enabled only for the East US location. 

**Azure subscription** 

You must have an Azure subscription. There are no specific limits to the type of subscription, but testing has not been completed for partner or free tier subscriptions. Please use a paid subscription for the Azure HPC Cache private preview. 

**Access permission and roles** 

The bulk of the service lies outside of your subscription and so you don’t need a great deal of permission to get started. However you will need to be able to create virtual NICs in the subscription. To do this you can either be the “Service Administrator” for the subscription (meaning that you have full control over everything) or you should assign your portal/Azure user the “Contributor” role. 

If you must have a more specific role, or questions about applying permissions to a specific scope such as an RG please contact 0c454b08.microsoft.com@amer.teams.ms with the specific requirements your environment requires. 

Resource Group – A regular resource group. You may use a common RG with other resources but if you have security requirements that require scoping you may want to consider using an RG dedicated to the HPC Cache environment (see Permissions/Roles above). 

A virtual network and a subnet – The Azure HPC Cache network interfaces will reside in a specific virtual network/subnet in your subscription.  BEST PRACTICE – You should create a dedicated subnet for the Azure HPC Cache to ensure there are no conflicts with IP address acquisition from other assets in your subscription.  

How large should my subnet be? Please plan on 64 addresses for the subnet. 

Should I install clients in the same subnet? – No. If the service has a failover issue it may lose an IP address previously used if at the same time another asset in that subnet attempts to bind one. That conflict is best avoided if you isolate the service instance. 

DNS – Please ensure that you use the default Azure DNS configuration as the service requires it for name resolution, shown below: 
 

 

NTP – Azure HPC Cache uses time.windows.com as its NTP server and will set that automatically.  