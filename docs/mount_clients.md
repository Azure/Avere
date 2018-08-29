# Mounting the Avere vFXT cluster

Follow these steps to connect client machines to access your vFXT cluster.

1. Configure a core filer and junction as described in [Configure storage](configure_storage.md)
1. Set up round-robin DNS for load distribution among the cluster nodes. Details are in [Configuring DNS for the Avere cluster](configure_dns.md).
1. Choose the IP address and junction path to mount, as explained below 
1. Issue the mount command, with appropriate arguments (described below) 

## IP addresses and paths

From your client, the ``mount`` command maps the cluster vserver to a path on the local filesystem.  

The vserver path is identified with its IP address, plus the path to the junction that you defined.

Example: ``mount 10.0.0.12:/avere/files /mnt/vfxt``

The IP address is one of the client-facing IP addresses defined for the vserver. You can find the range of client-facing IPs in the Avere Control Panel in two places:

* The VServers table in the Dashboard - 
 
  ![Dashboard tab of the Avere Control Panel with the VServer tab selected in the data table below the graph, and the IP address section circled](images/ip_addresses_dashboard.png)

* The Client Facing Network settings page - 

  ![Settings > VServer > Client Facing Network configuration page with a circle around the Address Range section of the table for a particular vserver](images/ip_addresses_settings.png)

The junction path corresponds to the **Namespace path** field you defined when creating the junction. For example, if you used ``/avere/files`` as your namespace path, your clients would mount *IP_address*:/avere/files to their local mount point. 

!["Add new junction" dialog with /avere/files in the namespace path field](images/create_junction_example.png)

In addition to the paths, include the options described below in your client mount command.

## Mount command arguments

To ensure a seamless client mount, pass these settings and arguments in your mount command: 

``mount -o hard,nointr,proto=tcp,mountproto=tcp,retry=30 ${VSERVER_IP_ADDRESS}:/${NAMESPACE_PATH} ${LOCAL_FILESYSTEM_MOUNT_POINT}``


| Required settings | |
--- | --- 
``hard`` | Soft mounts to the vFXT cluster are associated with application failures and possible data loss. 
``proto=netid`` | This option supports appropriate handling of NFS network errors.
``mountproto=netid`` | This option supports appropriate handling of network errors for mount operations.
``retry=n`` | Set ``retry=30`` to avoid transient mount failures. (A different value is recommended in foreground mounts.)

| Preferred settings  | |
--- | --- 
``nointr``            | The option "nointr" is preferred for legacy kernels (prior to 2008-Apr) that support this option. Note that the option "intr" is the default.