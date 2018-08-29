# Cluster tuning

Because of the diverse software and hardware environments used with the Avere cluster, and differing customer requirements, many vFXT clusters can benefit from customized performance settings. This step is typically done in conjunction with an Avere Systems representative, since it involves configuring some features that are not accessible in the Avere Control Panel.

The VDBench utlity can be helfpul in generating I/O workloads to test a vFXT cluster. Read [Measuring vFXT Performance](vdbench.md) to learn more. 

This section gives some examples of the kinds of custom tuning that can be done.

## General optimizations

These changes might be recommended based on dataset qualities or workflow style. 

- If the workload is write-heavy, increase the size of the write cache from its default of 20%. 

- If the dataset involves many small files, increase the cluster cache's file count limit. 

- If the work involves copying or moving data between two repositories, increase the number of parallel threads for moving data - or decrease the number of parallel threads if the back-end storage is becoming overloaded

- If the cluster is caching data for a core filer that uses NFSv4 ACLs, enable access mode caching to streamline file authorization for particular clients.

## Cloud NAS or cloud gateway optimizations

To take advantage of higher data speeds between the vFXT cluster and cloud storage in a cloud NAS or gateway scenario (where the vFXT cluster provides NAS-style access to a cloud container), Avere might recommend changing settings like these to more aggressively push data to the storage volume from the cache: 

- Increasing the number of TCP connections between the cluster and the storage container
- Decreasing the REST timeout value for communication between the cluster and storage to retry writes that don't immediately succeed sooner 
- Increase the segment size so that each backend write segment transfers an 8MB chunk of data instead of 1MB

## Cloud bursting or hybrid WAN optimizations

In a cloud bursting scenario or hybrid storage WAN optimization scenario (where the vFXT cluster provides integration between the cloud and on-premises hardware storage), these changes can be helpful:

- Increase the number of TCP connections allowed between the cluster and the core filer
- Enable the WAN Optimization setting for the remote core filer (This can be used for a remote on-premises filer or a cloud core filer in a different Azure region.)
- Increase the TCP socket buffer size (depending on workload and performance needs)
- Enable the "always forward" setting to reduce redundantly cached files (depending on workload and performance needs)
