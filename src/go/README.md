# Go Applications

This folder contains various utilities to test and demonstrate filer performance.

[CacheWarmer](cmd/cachewarmer/README.md) - The CacheWarmer warms a cache filer.  The primary use case is to improve time to first pixel rendered by VFX studios on their cloud render farm.

[Eda Simulator](cmd/edasim/README.md) - An Simulator that measures the performance of EDA workflows.

[VMScaler](cmd/vmscaler/README.md) - A vm manager that manages a VM farm of low priority VMSS nodes.  The primary use case is cloud burstable render farms by VFX rendering houses.