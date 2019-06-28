# HPC Cache Private Preview documentation - DRAFT 

This page provides partial documentation for the Azure HPC Cache private preview. Information is subject to change - please verify this information with your Microsoft Service and Support representative before using it in a production environment.

## Creating a cache 

### Cache sizing 

### Adding storage targets 

Storage targets are the long-term storage for the contents of your cache. 

#### Using the aggregated namespace 

The HPC Cache allows clients to access a variety of storage systems through a virtual namespace that hides the details of the back-end storage system. 

When you add a storage target, you set the client-facing filepath. Client machines mount this filepath. You can change the storage target associated with that path, for example to replace a hardware storage system with cloud storage, without needing to rewrite client-facing procedures. 


### Choose a usage model 

When you create a storage target, you need to choose the *usage model* for that target. This model determines how your data is cached. 


## Additional information

Details about the Azure HPC Cache will be available in late summer 2019. 

### Terms of service

This product is in Private Preview. Terms of Service will be made available in Public Preview or General Availability phases.

### Pricing

This product is in Private Preview. Pricing information will be made available in Public Preview or General Availability phases.
