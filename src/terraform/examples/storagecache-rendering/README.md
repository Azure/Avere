# Storage Cache Best Practices for Rendering

This document describes the storage cache best practices related to rendering.

# Pre-requisites

The following is a checklist of items to confirm before connecting an HPC Cache or Avere vFXT
* ensure your on-prem core filer has the following configured on the export
    * `no_root_squash` - this is needed because HPC Cache or vFXT works at the root level
    * `rw` - read/write is needed for the HPC Cache or vFXT to write files
    * **ip range is open** - ensure the HPC Cache or vFXT subnet is specified in the export.  Also, if any render clients are writing around, you will also need to open up the subnet range of the render clients, otherwise this is not needed.
* to choose a different vFXT image version, run the following command and use the value from the "urn" key:
```bash
az vm image list --location eastus -p microsoft-avere -f vfxt -s avere-vfxt-node --all
```
* ensure the on-prem firewall is open to the HPC Cache or vFXT subnets
* ensure an NFSv3 endpoint is enabled
* ensure you put a vFXT or HPC Cache into its own subnet.  The smallest subnet may be a /27.  The HPC Cache and Avere vFXT have HA models where they migrate IP addresses in HA events, and it is important that another cluster or another vm does not grab those IP addresses during migration.
* if you need to deploy a different image from default, there are two possible methods:
    1. get the SAS URL from Avere support and follow [the steps to create a custom image](../vfxt#create-vfxt-controller-from-custom-images) and populate the variable `image_id` with the URL of the image
    1. Alternatively, you can use an older version from the marketplace by running the following command and using the "urn" as the value to the `image_id`: `az vm image list --location westeurope -p microsoft-avere -f vfxt -s avere-vfxt-node --all`.  For example, the following specifies an older urn `image_id = "microsoft-avere:vfxt:avere-vfxt-node:5.3.61"`.

# Reducing TCO

* use a storage cache to reduce the bandwidth to the cloud, and reduce latency to on-premises filers.
* delete the HPCCache or the Avere vFXT when not in use.
* for the lowest TCO, automate the deployment and teardown the HPC Cache or the Avere vFXT.  Terraform examples are available in this repository for both HPC Cache, and Avere vFXT
* for the Terraform vFXT provider, ensure you use only 3 nodes and the lowest memory to save on storage with the following Terraform:
```bash
    vfxt_node_count = 3
    node_cache_size = 1024
```
* for the Terraform vFXT provider, during dev-test cycles where the Avere is not in production, use the unsupported test SKU:
```bash
    node_size = "unsupported_test_SKU"
```

# Mapping Shares

When designing your architecture, you will need to consider how to map the drives between on-prem and cloud.  The cloud render nodes will map to the Avere, and the on-prem render nodes will map to the core filer.

The easiest way to ensure consistency across on-prem and cloud is to "Spoof" the dns name using a solution similar to binding the [unbound](../dnsserver) DNS server to your VNET.  For NFS and SMB shares with posix access the render nodes and cloud nodes can use the same domain name for mapping.

However, the mapping becomes more challenging when using mixed Windows / Linux environments, or using constrained delegation with SMB.  Here are some possible solutions to work around this:
1. Use the render software organization.  Formats like the Maya Ascii format (.ma files) allow for specification of project path, and this will rewrite the base.  This is probably the best solution for mixed Windows / Linux environments.  Refer to [dirmap documentation](https://help.autodesk.com/cloudhelp/2016/ENU/Maya-Tech-Docs/Commands/dirmap.html) for more information.  Additionally compositing tool [Nuke](https://learn.foundry.com/nuke/content/comp_environment/configuring_nuke/file_paths_cross_platform.html) and render managers like [Royal Render](http://www.royalrender.de/help7/index.html?Pathsanddrives.html) provide options for adjusting mapping in different environments.
1. If Windows only, and using constrained delegation, map a drive letter, or create a directory symbolic link (mklink /D).

# SMB

For SMB ensure you set the UID / GID attributes according to the [Avere SMB document](https://azure.github.io/Avere/legacy/pdf/ADAdminCIFSACLsGuide_20140716.pdf).  SMB is only supported on NetApp and Isilon.  SMB is unqualified but working on PixStor and Qumulo.  Use the following documents to help you with these core file types:
* [PixStor](Avere%20and%20PixStor%20with%20SMB%20Shares.pdf) - shows how to configure Avere with PixStor.
* [Qumulo](Avere%20and%20Qumulo%20with%20SMB%20Shares.pdf) - shows how to configure Avere with Qumulo.

For SMB the Avere cluster configuration should be:
1. 3-node cluster only.  To scale, add multiple 3-node clusters and ensure cache policy set to '`Clients Bypassing the Cluster`'.
1. In SMB only environments, ensure global custom setting `"cluster.pruneNsmMonitorEnabled UO false"` is added to clusters running SMB.  Advice void after July 1, 2021.
1. vserver should be configured to have single IP address per node
1. set domain controller override to ensure Avere only accesses the domain controllers that are allowed by the firewall.

If you are using a system that requires RID, use the [RID Generation Script](../houdinienvironment/Get-AvereFlatFiles.ps1), and copy the files alongside main.tf, and pass them in as `cifs_flatfile_passwd_b64z` and `cifs_flatfile_group_b64z` as shown in the [Houdini cache example](../houdinienvironment/3.cache/main.tf).

If you have a Netapp or EMC Isilon storage filer, you can enable NTFS ACLS.  Otherwise you will need to rely on [RFC2307](https://tools.ietf.org/html/rfc2307) and the conversion policy on the file.  The conversion to/from POSIX ACLs to NTFS ACLS is lossy, and is described as the [The ACL interoperability Problem](https://wiki.linux-nfs.org/wiki/index.php/ACLs#The_ACL_Interoperability_Problem).

To ensure the best operability between POSIX and NTFS ACLS, ensure you have investigated the following:

1. share folder should have the correct group used for render and a mask of 770, and for NTFS acl do the similar thing and confirm that Everyone has no actions available.

2. Filer SMB and NFS - 770 mask for file create and dir masks

3. On Avere, ensure 0770 for file and dir masks, remove Everyone ACE.

To mount SMB from Linux, run a command similar to the following:

```bash
# please update:
#   AVEREVFXTADDRESS - replace with Avere vFXT dns name
#   uid=0 - replace with the most appropriate UID 
#   gid=1000 - replace with the group that you want to use
#   file_mode=0770,dir_mode=0770 - replace with the correct modes, eg 775
sudo mount -t cifs -o credentials=/secret.txt,vers=2.0,rw,sec=ntlmssp,cache=strict,uid=0,noforceuid,gid=1000,noforcegid,file_mode=0770,dir_mode=0770,nounix,serverino,mapposix \\\\AVEREVFXTADDRESS\\assets /mnt/assets
```

## SMB Performance and Latency

The following table shows the performance of a single threaded download of the [Moana Island Scene](https://www.disneyanimation.com/resources/moana-island-scene/) with SMB.  The scene included 339 pbrt files and a total of 15 GB.

| Description | Latency | Time (minutes:seconds) |
| --- | --- | --- |
| SMB2.0.2 cloud direct to onprem NAS | 26 ms | 9:22 |
| SMB3.1.1 cloud direct to onprem NAS | 26 ms | 2:22 |
| SMB2.0.2 to Avere vFXT (cold) to onprem NAS | <1ms (26ms from vFXT to on-prem) | 5:45 |
| SMB2.0.2 to Avere vFXT (warm) to onprem NAS | <1ms (26ms from vFXT to on-prem) | 1:25 |

The conclusions that can be made:
1. SMB 3.1.1 performs much better over a high latency link than SMB 2.0.2
1. Avere hides the latency, preserves bandwidth, and a warm cache will perform better than SMB 3.1.1 over a high latency link.

## Troubleshooting SMB

To troubleshoot the ACL problem the following two scenarios show a write from on-prem and a write from a render node in the cloud.

Also, use the [SMB Walker](../../../go/cmd/smbwalker) that will walk all shares, to help troubleshoot issues.

### Problem #1 - Writing from a Windows Machine on-prem

The first scenario shows writing a file from on-prem.  In this example, only the NTFS ACL gets written.  The POSIX ACL is not set, and when the file crosses the NFSv3 boundary to the Avere, the NTFS ACL is sliced off, and access is denied to the render nodes.

![Writing a file from on-prem](acl-write-from-onprem.png)

You can solve this problem in the following ways:
1. Look at the create and directory masks policies of the Core Filer, and these would be adjusted to `770` to allow for owner and groups.  For example, here are the [create](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#CREATEMASK) and [directory mask](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#DIRECTORYMASK) configurations for samba.
1. run `chmod -R 770 DIR` on the directory, or setup a cron job on the local core filer.  This step is usually a last resort.

### Problem #2 - Writing from a Windows Machine through the Avere

The second scenario shows writing a file from the render node through the Avere to on-premises.  In this scenario, the Avere writes the POSIX ACL, but when the file lands on the core filer, the NTFS ACL is missing.  File access is then denied to on-premises Windows user, because the empty NTFS ACL is converted to an empty Windows ACL.

![Writing a file from a cloud render node through Aver to on-prem](acl-write-from-cloud.png)

You can solve this problem in the following way:
1. Look at the conversion policy from POSIX to NTFS ACLs on the filer.
1. run an NTFS acl command, something like the following `setfacl -R .... DIR` on the directory, or setup a cron job on the local core filer.  This step is usually a last resort.
