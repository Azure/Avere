# Hammerspace Reference SKUs

The following table shows the performance characteristics of various Azure SKUs:

| Azure SKU | Disk Type | Capacity (TiB) | VM Max Throughput (GB/s) | VM IOPs |
| --- | --- | --- | --- | --- |
| Standard_F8s_v2 (good for POC) | managed disk | [see managed disks config](https://azure.microsoft.com/en-us/pricing/details/managed-disks/) | 0.19 GB/s | 12800 |
| Standard_F16s_v2 | managed disk | [see managed disks config](https://azure.microsoft.com/en-us/pricing/details/managed-disks/) | 0.38 GB/s | 25600 |
| Standard_D14_v2 | managed disk | [see managed disks config](https://azure.microsoft.com/en-us/pricing/details/managed-disks/) | 0.768 GB/s | 51200 |
| Standard_L4s | ssd | 0.56 TiB | 0.20 GB/s | 20000 |
| Standard_L8s | ssd | 1.15 TiB | 0.39 GB/s | 40000 |
| Standard_L16s | ssd | 2.33 TiB | 0.78 GB/s | 80000 |
| Standard_L32s | ssd | 4.68 TiB | 1.56 GB/s | 160000 |
| Standard_L8s_v2 | nvme | 1.92 TiB | 0.39 GB/s (limited by NIC) | 400000 |
| Standard_L16s_v2 | nvme | 3.84 TiB | 0.78 GB/s (limited by NIC) | 800000 |
| Standard_L32s_v2 | nvme | 7.68 TiB | 1.56 GB/s (limited by NIC) | 1.5M |
| Standard_L48s_v2 | nvme | 11.52 TiB | 1.95 GB/s (limited by NIC) | 2.2M |
| Standard_L64s_v2 | nvme | 15.36 TiB | 1.95 GB/s (limited by NIC) | 2.9M |
| Standard_L80s_v2 | nvme | 19.2 TiB  | 1.95 GB/s (limited by NIC) | 3.8M |

# Rendering SKUs

Here are recommended Hammerspace Configurations specific to Rendering:

| Rendering SKU | Anvil HA | Anvil Instance | Anvil Disk Size (GB) | DSX Instance | DSX Instance Count | Disk Size Per VM (GB) |
| --- | --- | --- | --- | --- | --- | --- |
| Test SKU | False | Standard_F8s_v2 | 127 GB | Standard_F8s_v2 | 1 | 511GB |
| Artist SKU | True | Standard_F16s_v2 | 256 GB | Standard_DS14_v2 | 3 | 1024GB |
| Render SKU | True | Standard_F16s_v2 | 256 GB | Standard_L32s_v2 | 3 | N/A |