# Maya + Azure Batch + Avere vFXT Demo

This 60 minute demo takes you through a Maya + Batch + Avere vFXT Demo.  By the end of the demo you will have made a movie using Maya + Azure Batch + Avere vFXT.

# Pre-requisites

1. Install a vFXT according to [Marketplace vFXT deployment](MicrosoftAverevFXTDeployment.md).

2. On the controller, mount the vFXT shares:
    1. run the following commands:
    ```bash
	sudo -s
	apt-get update
	apt-get install nfs-common
	mkdir -p /nfs/node1
	mkdir -p /nfs/node2
	mkdir -p /nfs/node3
	chown nobody:nogroup /nfs/node1
	chown nobody:nogroup /nfs/node2
	chown nobody:nogroup /nfs/node3
	```

	2. Edit `/etc/fstab`, and add the following lines, *updating the ip addresses to match the vFXT*, and adding more lines if you built a larger cluster:
    ```bash
	172.16.0.12:/msazure	/nfs/node1	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
	172.16.0.13:/msazure	/nfs/node2	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
	172.16.0.14:/msazure	/nfs/node3	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
	```

	3. To mount all shares, now type `mount -a`

3. Install a Windows 10 Avere Mounted Workstation according to [Windows 10 Avere vFXT Mounted Workstation](Windows10AverevFXTMountedWorkstation.md).

# Prepare Content

1. Use the Windows 10 Workstation or Controller to download a maya scene to the controller's `/mnt/scene` folder.  This demo uses the walking skeleton demo from https://www.turbosquid.com/3d-models/3d-model-kong-skeleton-1192846.

2. 