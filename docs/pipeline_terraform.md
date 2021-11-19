## Automation for Terraform VFXT Pipeline:
Terraform vFXT automation has multiple configrations that can be ran. The main file for the automation is called [terraform.yml](../terraform.yml). The template files are located in the [templates](../templates) directory. The automation in ran on Azure Pipelines. It initially creates a new VM to be the runner and is set-up using this [configuration](../templates/cloud_init/cloud_init.client.yml).

### Automated cases
- [Avere vFXT with azureblobfiler](../src/terraform/examples/vfxt/azureblobfiler)
- [Avere vFXT with Proxy](../src/terraform/examples/vfxt/proxy)
- [Avere vFXT with 1-filer](../src/terraform/examples/vfxt/1-filer)

TODO: make cluster name unique
### Scale-up and Scale-down nodes
- Number of nodes to scale:+-1     +-3
- Scale-down is only ran if scale-up previously ran. It is a no-op if only scaledown is chosen.

### VdBench:
Automation only runs with the [azureblobfiler](../src/terraform/examples/vfxt/azureblobfiler) configuration.

**TODO:**
- Automate [nfsfiler](../src/terraform/examples/vfxt/vdbench/nfsfiler/main.tf)

The configurations implemented:
- [vdbench-inmem](../src/terraform/examples/vfxt/vdbench) - 20 minutes
- [vdbench-ondisk](../src/terraform/examples/vfxt/vdbench) - 40 minutes
  - If running scale up and scale down, vdbench-ondisk is a failing scenario.

Currently if vdbench is selected. It is kicked off and then goes into scale-up if that is selected. If nothing is selected, then it waits for vdbench completion.

Notes:
1. Cluster starting node count is currently 3.
2. Cluster scaling increment is 1 node at a time.
3. Cluster Scaling Target:
    - target time for scale up: (<40 minutes)
    - target time for scale down: (<30 minutes)
4. Corefiler backend:
    - 1-filer (nfs - nasfiler1)
    - proxy (nfs - nasfiler1)
5. Junction: caching policy
    - azureblobfiler = (none - is azure storage container, clfs st)
    - 1-filer = ("Clients Bypassing the Cluster")
    - proxy = ("Clients Bypassing the Cluster")
    - The caching policy has to be run in this mode, scaleup/scaledown only support "ClientsBypassingtheCluster" aka write-around.
    - **POTENTIAL_TODO:** Read-Write as caching policy, not implemented yet for scaleup/scaledown.
6. Vdbench Configurations that are created from bootstrap.vdbench.sh
    - inmem.conf
    - ondisk.conf
    - inmem32.conf
    - 3node_inmem32.conf
    - 6node_inmem32.conf
    - 3node_32_ondisk.conf
    - 6node_32_ondisk.conf

    - **TODO:** Update the .conf files. Remove the maxdata and replace with elapsed=time_in_seconds
        - Bootstrap script:
        ```
            https://github.com/Azure/Avere/blob/main/src/clientapps/vdbench/bootstrap.vdbench.sh#L337
            replace maxdata=432g   ->  elapsed=seconds
        ```

    - **TODO**: Change Test Structure of pipeline
        Serialized w/ Parrallel runs.
        sed initial .conf
        create 4 files and associated runs:
        - ondiskscaleup1.conf   / vdbench(40) / scaleup   (+1)
        - ondiskscaledown1.conf / vdbench(30) / scaledown (-1)
        - ondiskscaleup3.conf   / vdbench(?) / scaleup   (+3)
        - ondiskscaledown3.conf / vdbench(?) / scaledown (-3)

7. Number of clients
   - Option to decide between 6 and 12 instances.
8. VM skus of clients
   - Standard_D2s_v3
9. Client mount distribution (all clients mount the cache)

   - Mounts on each VMSS:
    ```
    10.0.1.11:/storagevfxt on /data/node0 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.0.1.11,mountvers=3,mountport=4046,mountproto=tcp,local_lock=none,addr=10.0.1.11)
    10.0.1.12:/storagevfxt on /data/node1 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.0.1.12,mountvers=3,mountport=4046,mountproto=tcp,local_lock=none,addr=10.0.1.12)
    10.0.1.13:/storagevfxt on /data/node2 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.0.1.13,mountvers=3,mountport=4046,mountproto=tcp,local_lock=none,addr=10.0.1.13)
    ```

