# Azure Terraform NFS based IaaS NAS Filer using ephemeral storage

This is the Azure Terraform implementation of an NFS based IaaS NAS Filer using ephemeral storage.

The following examples show how to use this module:
* [Deploy IaaS NFS NAS filer](../../examples/nfsfiler)
* [Deploy IaaS NFS NAS filer and mount with an HPC cache](../../examples/HPC%20Cache/1-filer)
* [Deploy IaaS NFS NAS filer and mount with an Avere vFXT cache](../../examples/vfxt/1-filer)

The following table shows the performance characteristics of various Azure SKUs:

| Azure SKU | Ephemeral Disk Type | Capacity (TiB) | Storage Throughput (GB/s) | IOPs |
| --- | --- | --- | --- | --- |
| Standard_D2s_v3 (good for POC) | ssd | 0.04 TiB | 0.04 Read GB/s, 0.02 Write GB/s  | 3000 |
| Standard_D32_v3 (good for POC) | ssd | 0.78 TiB | 0.73 Read GB/s, 0.37 Write GB/s  | 48000 |
| Standard_L4s | ssd | 0.56 TiB | 0.20 GB/s | 20000 |
| Standard_L8s | ssd | 1.15 TiB | 0.39 GB/s | 40000 |
| Standard_L16s | ssd | 2.33 TiB | 0.78 GB/s | 80000 |
| Standard_L32s | ssd | 4.68 TiB | 1.56 GB/s | 160000 |
| Standard_L8s_v2 | nvme | 1.92 TiB | 0.39 GB/s (limited by NIC) | 400000 |
| Standard_L16s_v2 | nvme | 3.84 TiB | 0.78 GB/s (limited by NIC) | 800000 |
| Standard_L32s_v2 | nvme | 7.68 TiB | 1.56 GB/s (limited by NIC) | 1.5M |
| Standard_L48s_v2 | nvme | 11.52 TiB | 1.95 GB/s (limited by NIC) | 2.2M |
| Standard_L64s_v2 | nvme | 15.36 TiB | 1.95 GB/s (limited by NIC) | 2.9M |
| Standard_L80s_v25 | nvme | 19.2 TiB  | 1.95 GB/s (limited by NIC) | 3.8M |
| Standard_M128s | ssd | 4.0 TiB | 1.56 GB/s | 160000 |
