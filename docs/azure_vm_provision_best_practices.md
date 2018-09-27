# Best Practices for Improving Azure Virtual Machine Boot Time

September 2018

The Avere Virtual FXT (vFXT) Edge Filers act as network-attached storage (NAS) in the cloud and support burstable high-performance computing (HPC) workloads. A common question we hear from customers is how to boot thousands of virtual machines (VMs) quickly on Azure. 

Our first answer to customers is to investigate the Azure managed solutions such as [Azure CycleCloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/) and [Azure Batch](https://azure.microsoft.com/en-us/services/batch/). These two solutions remove the complexity of booting HPC sized compute workloads.

However, some customers still want to deploy their own workloads from scratch or want the ability to fine tune and add features from the [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates). For these customers we did not have a best practices guide. This document explores booting 1000 VMs and provides some best practices for deploying VMs quickly on Azure.

The main questions of this document are:
  1. What is the fastest way to deploy 1000 VMs?

  2. Can the Avere vFXT be used to serve large binary/toolchain payloads to result in improved deployment times?

This document first starts with hypotheses for these questions, and then runs various experiments to prove or disprove the hypotheses and finally concludes with best practices. Some of the best practices learned in this study can further help improve speed of boot times with [Azure CycleCloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/), and [Azure Batch](https://azure.microsoft.com/en-us/services/batch/).

## Hypothesis

We had the following hypotheses for the fastest way to boot 1000 VMs:

1. Platform images will deploy significantly faster than custom images.

2. Downloading large binary/toolchain payloads from the Avere vFXT will improve VM deployment time over having the binaries and tools preloaded on the OS disk.

3. If #2 holds true, further scaling the Avere vFXT horizontally will provide linear improvement in boot time.

4. [Virtual Machine Scale Sets (VMSS)](https://azure.microsoft.com/en-us/services/virtual-machine-scale-sets/) will be faster than availability sets VMs or loose VMs.

## Experiment Setup

Here is the setup for the experiment:

1. Pick a region, and ensure enough quota exists for 1000 DS2v2 VMs. We chose DS2v2 because it has enough [Blob cache](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series) to hold large binary/toolchain payloads.

2. Deploy a virtual network and storage account, and create an Avere vFXT cluster using these [deployment instructions](https://github.com/Azure/Avere/blob/master/docs/jumpstart_deploy.md). 

    Cluster details: 

    - Three nodes of Standard_E32s_v3 instances
    - Per-node cache size: 8192GB
    - Blob storage backend

3. Add a subnet named "batch" to the three-node cluster's VNet, with address space to support 1000 nodes. For this experiment we used `10.0.16.0/20` for our address space.

4. Deploy another VNet and storage account, and create a six-node Avere vFXT cluster using the same options as the three-node cluster in step 2. 

5. Add a subnet named "batch" to the six-node cluster's VNet, with address space to support 1000 nodes. For this experiment we used `10.0.16.0/20` for our address space.

6. Download and build the [deployer utility](https://github.com/anhowe/azure-util/tree/master/deployer) and associated templates. This will be used for deploying the VMs.

7. For resource group deletion, download and build the [deleterg utility](https://github.com/anhowe/azure-util/tree/master/deleterg).

8. Create an event hub using the following [instructions](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-go-get-started-send) and capture the following:
    1. Event hub namespace name
    2. Event hub name
    3. Event hub key name
    4. Event hub key

9. If you don't already have a service principal for your subscription, create a service principal using [these instructions](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?toc=%2Fen-us%2Fazure%2Fazure-resource-manager%2Ftoc.json&bc=%2Fen-us%2Fazure%2Fbread%2Ftoc.json&view=azure-cli-latest) and capture the following:
    1. Tenant ID
    2. Client ID
    3. Client Secret
 
10. Create an Ubuntu 18.04 custom image, and capture it using these [instructions](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image). Before running capture, prepare the VM image by running the following commands:
    1. `sudo -s`
    2. `apt-get update`
    3. `apt-get install -y parallel nfs-common`
    4. `mkdir -p /opt`
    5. `curl --retry 5 --retry-delay 5 -o /usr/bin/parallelcp https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/parallelcp`
    6. `curl --retry 5 --retry-delay 5 -o /opt/create1GBfiles.sh https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/create1GBfiles.sh`
    7. `curl --retry 5 --retry-delay 5 -o /opt/create5GBfiles.sh https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/create5GBfiles.sh`
    8. `chmod +x /usr/bin/parallelcp`
    9. `chmod +x /opt/create1GBfiles.sh`
    10. `chmod +x /opt/create5GBfiles.sh`
    11. `mkdir -p /opt/tools1GB && /opt/create1GBfiles.sh /opt/tools1GB`
    12. `mkdir -p /opt/tools5GB && /opt/create5GBfiles.sh /opt/tools5GB`

11. Set up each Avere vFXT cluster with the following:
    1. From the client VM - 
        1. `apt-get update`
        2. `apt-get install -y parallel nfs-common`
        3. `mkdir -p /opt`
        4. `curl --retry 5 --retry-delay 5 -o /usr/bin/parallelcp https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/parallelcp`
        5. `curl --retry 5 --retry-delay 5 -o /opt/create1GBfiles.sh https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/create1GBfiles.sh`
        6. `curl --retry 5 --retry-delay 5 -o /opt/create5GBfiles.sh https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/create5GBfiles.sh`
        7. `mkdir -p /mnt/tools1GB && /opt/create1GBfiles.sh /mnt/tools1GB`
        8. `mkdir -p /mnt/tools5GB && /opt/create5GBfiles.sh /mnt/tools5GB`
        9. `mkdir -p /nfs/avere`
        10. mount the avere cluster with a command similar to the following `mount 10.0.0.5:/msazure /nfs/avere`.
        11. `parallelcp /mnt/tools1GB /nfs/node1/tools1GB`
        12. `parallelcp /mnt/tools5GB /nfs/node1/tools5GB`
        13. `mkdir /nfs/node1/bootstrap`
    2. Download and build the [eventhubsender utility](https://github.com/anhowe/azure-util/tree/master/eventhubsender) and save to `/nfs/avere/boostrap`
    3. `curl --retry 5 --retry-delay 5 -o /nfs/avere/boostrap/bootstrap.sh https://raw.githubusercontent.com/anhowe/azure-util/master/deployer/templates/bootstrap.sh`

Then with each template from the [deployer utility](https://github.com/anhowe/azure-util/tree/master/deployer) directory, perform an experiment of booting 1000 VMs.

## Results

We broke our experiment up into two phases:

  1. Phase 1: Determine the fastest way to boot 1000 VMs.

  2. Phase 2: How much does Avere vFXT improve the delivery of the large binary/toolchain payloads?
 
### Phase 1: Determine the fastest way to boot 1000 VMs

Our first few experiments immediately ran into issues where our P95 deployment time was 26 minutes, and our P100 was around 47 minutes. We found solutions for each of the problems and they are listed in the following sub sections.

#### Heavy ARM Throttling on Create

During create we would see a long tail of deployment times, and also the following error message from ARM (as seen from https://resources.azure.com):

```json
"details": [
    {
    "code": "TooManyRequests",
    "target": "GetOperation30Min",
    "message": "{\"operationGroup\":\"GetOperation30Min\",\"startTime\":\"2018-09-18T11:44:38.1546086+00:00\",\"endTime\":\"2018-09-18T11:59:38.1546086+00:00\",\"allowedRequestCount\":30000,\"measuredRequestCount\":37352}"
    }
]
```

When creating 1000 VMs, it creates 1000 NICs, 1000 VMs, 1000 disks, and 1000 custom script extensions. These resources were submitted as templates through ARM. As ARM polled status on all these resources, it exhausting the request budget for the subscription.

To solve this, we implemented the following workarounds:
    1. Eliminate the custom script extension, eliminating 1000 resources that needed status checks.
    2. Run all custom script extension commands through "cloud-init".
    3. Reduce polling from our script.
    4. Add event hub hooks in the [deployer utility](https://github.com/anhowe/azure-util/tree/master/deployer), and have every VM use the [eventhubsender utility](https://github.com/anhowe/azure-util/tree/master/eventhubsender) to signal completion.
    5. Submitted case 84593165 to resolve the issue long term.

If you wanted multiple thousands of VMs, it might be best to create a subscription for each block of 1000 VMs to work around these throttling limitations.

#### Heavy ARM Throttling on Delete

Deletion of resource groups containing the 1000 VMs would take 90 minutes to delete, and result in the following error message:

```json
{
  "error": {
	"details": [
	  {
		"code": "TooManyRequests",
		"target": "DeleteVM30Min",
		"message": "{\"operationGroup\":\"DeleteVM30Min\",\"startTime\":\"2018-09-18T15:13:12.093203+00:00\",\"endTime\":\"2018-09-18T15:28:12.093203+00:00\",\"allowedRequestCount\":3014,\"measuredRequestCount\":5446}"
	  }
	],
	"code": "OperationNotAllowed",
	"message": "The server rejected the request because too many requests have been received for this subscription."
  }
}
```

The main solution here was to stagger the deletes of the resource groups as captured in the [deleterg utility](https://github.com/anhowe/azure-util/tree/master/deleterg). To resolve long term we have submitted case 84854892.

#### Throttling from Ubuntu Package Updates

For the platform images, we encountered throttling from the Ubuntu servers that had the following error message: `Unable to connect to azure.archive.ubuntu.com:http:`.

The solution here was to wrap the apt commands in retry. Another possibility here is to try to [pre-download packages](https://www.ostechnix.com/download-packages-dependencies-locally-ubuntu/) and store them on Azure storage. We would then have to contend with storage throttling. 

#### 40-Minute Nodes

Occasionally one or two nodes would take 40 minutes to boot, whereas all others were less than five minutes. The solution here was to over-provision by one or two and prune the tardy VMs. We were careful to rule out ARM throttling in this case, because over-provisioning with ARM throttling would make the deployment time tail longer.

#### Boot Results

Once we resolved the above performance issues, we were able to get the timings for booting 1000 VMs from Ubuntu 18.04 platform and custom images. The results of the percentiles of the seconds to boot are shown following chart. We did not notice a performance difference between platform images and custom images, invalidating our first hypothesis.

   <img src="images/vm_boot/boot_time_1000vms_results.png">

Once we understood how to boot VMs quickly, we next looked at how to prepare the large binary/toolchain payload. In our experience, we have seen that customers require binaries or toolchains in the size range of 1GB to 5GB. These toolchains depend on the vertical and could be used for rendering, genomics processing, and financial modeling. Based on this understanding, we recorded the timings for 1GB and 5GB binaries.

In the next round of experiments we "warmed" our toolchains by reading all bits of the toolchain, and thereby populating the Blob cache.  The purpose of "warming" is to ensure the VM is ready to perform work. A VM that has booted quickly is of no use if the first read on the toolchain takes 30 minutes. To "warm" the toolchain we copied all the bits from the toolchain on the OS disk to the ephemeral drive (from /opt/tools to /mnt/tools).

Since we are using a DS2_v2 VM size, we have [8GB of local cache](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series). This means we will have enough room in the Blob cache to hold either the 1GB or 5GB binary. In summary, each premium VM has a Blob cache that stores recently used data in RAM and SSDs locally as shown in the following image. This is described in more detail in the [Premium Storage GA announcement](https://azure.microsoft.com/en-us/blog/azure-premium-storage-now-generally-available-2/).

<p align="center">
   <img src="http://acom.azurecomcdn.net/80C57D/blogmedia/blogmedia/2015/06/22/VM_medium_thumb.png" width="350">
</p>

Here are the percentiles of seconds to boot and "warm" a 1GB toolchain from bits stored on the custom image:

   | Percentile | Loose VMs | VM Availability Sets | VM Scale Sets |
   | --- | --- | --- | --- |
   | VMs Per Availability Set or VMSS | 1 | 25 | 250 |
   | Failure Count | 0 | 0 | 0 |
   | P50 | 557 | 512 | 526 |
   | P95 | 698 | 618 | 615 |
   | P100 | 901 | 707 | 661 |

Here are the percentiles of seconds to boot and "warm" a 1GB tool chain from bits stored on the custom image:

   | Percentile | Loose VMs | VM Availability Sets | VM Scale Sets | VM Scale Sets |
   | --- | --- | --- | --- | --- |
   | VMs Per Availability Set or VMSS | 1 | 25 | 250 | 25 |
   | Failure Count | 8 | 10 | 0 | 13 |
   | P50 | 1617 | 1853 | 749 | 1766 |
   | P95 | 1920 | 2260 | 1147 | 2004 |
   | P100 | 2038 | 2379 | 1235 | 2036 |

On the 5GB "warming" we hit some form of threshold in the stack where the VM boot tail grew as signified by the P100 time. We also started seeing multiple VM failures. Most of the failures we saw were because the VM rebooted and interrupted the deployment process.  The VMSS VMs outperformed the loose VMs and the availability set VMs. After running this experiment we ran an additional experiment, where we reduced the VMSS to 25 VMs per VMSS, and we ended up with much worse performance and an increase in failures. This led to a conclusion that a large VMSS group scales much better than many smaller ones.

### Phase 2: How much does Avere vFXT improve the delivery of the large binary/toolchain payloads?

The next phase of the experiment was to determine how to use the Avere vFXT to improve boot time by using it to serve the 1GB and 5GB binary/toolchain payloads. Our first few runs against the Avere proved slow. Upon further investigation we realized we had to disable "always forward" for this read workload. The "always forward" on the Avere vFXT treats all the RAM and disk memory across the Avere nodes as one shared pool. In this way, the more nodes you add, the larger your shared cache. The downside is that the probability of introducing a network hop is the inverse of your node count-1. Disabling "always forward" reduces the cache size to the amount of RAM/disk space on a single machine, but completely eliminates the network hop.

Disabling "always forward" is an advanced command-line setting on the Avere vFXT cluster. From the cluster controller VM, SSH as root to the management IP address for the cluster. This will connect you to a vFXT node in the cluster. Log in using the administrative password you set for the cluster and run the following commands:

```bash
averecmd support.setCustomSetting mass1.always_forward OZ 0 "comment"
averecmd support.setCustomSetting vcm.always_forward ZZ 0 "comment"
```

After we disabled always forward we saw a steady 5.5 GB/s from our three-node Avere vFXT cluster, and a steady 11 GB/s from our six-node Avere vFXT cluster, as shown in the following images. These numbers demonstrated that Avere vFXT clusters have great horizontal scaling.

   <img src="images/vm_boot/3_node_vfxt_max.png">

   <img src="images/vm_boot/6_node_vfxt_max.png">

We then collected the timings for the 1GB and 5GB payloads in the following configurations:
 * Mount the three-node Avere vFXT and copy payload from Avere vFXT to the OS disk of the platform image
 * Mount the three-node Avere vFXT and copy payload from the Avere vFXT to the OS disk of the custom image
 * (5GB only) Mount the six-node Avere vFXT and copy payload from the Avere vFXT to the OS disk of the custom image
 * (5GB only) Mount the six-node Avere vFXT and copy 5GB payload from the Avere vFXT to the ephemeral drive ("warming the cache for the NFS mount")
 * (5GB only) Mount the six-node Avere vFXT and copy 5GB payload from the Avere vFXT to the ephemeral drive ("warming the cache for the NFS mount")

 The results for the 1GB warming runs are summarized in the following chart. The results show that copying 1GB payloads from Avere results in slight performance increases in all cases but the loose VMs.

   <img src="images/vm_boot/boot_time_1000vms_and_warm_1GB_results.png">

The results for the 5GB warming runs are summarized in the following chart. The first three column of results show retrieval of the 5GB payload from the OS disk of the custom image as found in Phase 1 of the experiment. The following observations can be seen:
 * As previously discussed, large VMSS groupings (250 VMs per VMSS) significantly outperform the small VMSS groupings (25 VMs per VM)
 * For the loose VMs and the availability set VMs, copying from the Avere vFXT improves the timings, and also reduces the occurrences of VM failures
 * Using the payload directly from the Avere vFXT NFS share shows performance improvements across all VM configurations

   <img src="images/vm_boot/boot_time_1000vms_and_warm_5GB_results.png">

The fastest configuration for booting 1000 VMs with a 5GB toolchain payload was the following:
 * Four VMSS resources each with 250 custom image VMs
 * Mount a six-node Avere vFXT for the toolchain payload

## Conclusion

The above experiments revealed many conclusions about how to make VMs boot faster on Azure. All but one of our hypotheses are correct. The hypothesis stating that platform images are going to be significantly faster than custom images is incorrect.  Platform images are slightly faster in some cases, and slightly slower in other cases.

In conclusion, here are the best practices to achieve the best VM bootup times on Azure and avoid long boot time tails.

  1. **Use a managed service for VM creation** - Before deploying VMs directly, consider using an Azure managed service like [Azure CycleCloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/) or [Azure Batch](https://azure.microsoft.com/en-us/services/batch/). This hides all the complexity and issues we encountered in this experiment.

  2. **Reading large binary/toolchain payloads from the custom image are slow for all VM configurations but VMSS** - Warming the cache by reading a large binary payload from a custom image is slow for loose VMs and availability set configurations. Additionally the larger the binary/toolchain payload the greater the spike in VM failures. In our configuration we were running Ubuntu, which requires about 400-500 MB to boot and reading the toolchain. We suspect for larger OSes like Windows, we will get less GB of toolchain to download before we see a spike in VM failures and a long deployment time tail.

  3. **Use an Avere vFXT to deliver large binary/toolchain payloads** - The fastest boot times resulted when VMs were able to mount the Avere vFXT directly, and consume the binary/toolchain payloads directly from the Avere vFXT. This also resulted in fewer rebooted VMs.  This best practice can also be combined when booting with [Azure CycleCloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/) and [Azure Batch](https://azure.microsoft.com/en-us/services/batch/).

  4. **The Avere vFXT scales linearly as you add more nodes** - Our experiments showed that the Avere vFXT linearly scaled in throughput as more nodes were added.

  5. **Use VMSS** - If you are unable to use a managed service, then your next best option is VMSS. As shown in our experiments VMSS consistently out performed availability sets and loose VMs.
      
  6. **Use a large count of VMs per VMSS** - We found that VMSS worked better when we had a large number of VMs per VMSS. For our experiments we used 250 VMs per VMSS. When we tried 40 VMs per VMSS the performance was significantly worse and also resulted in failed VMs.

  7. **Manage your ARM calls** - ARM throttling was our first major problem to overcome. Once you start getting throttled, any over-provisioning to get faster times will actually increase your deployment tail. Techniques used above included using cloud-init instead of custom script extension, staggering ARM calls, and reducing polling. Additionally, using multiple subscriptions will also help work around these issues.

  8. **Loose VMs are slow** - Loose VMs were always the slowest to boot and had the longest deployment time tails.  If you want to use loose VMs consider grouping them by availability sets to get better performance.
