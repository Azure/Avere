# Backup any FXT or vFXT cluster and Restore to HPC Cache or Avere vFXT for Azure

This examples shows how to capture a backup of any FXT or vFXT cluster.  This backup can then be used to build Terraform for HPC Cache or Avere vFXT for Azure, and these files can be used to deploy to Azure, and fully automate deployment / teardown of the HPC Cache or Avere vFXT for Azure cluster.

## Instructions

1. Get the `config_restore.sh` script from Avere support.

2. (Skip to step 3 if you have direct IP address to a FXT or vFXT node) scp the `config_restore.sh` to the Avere controller and ssh to the controller.

```bash
scp config_restore.sh CONTROLLER_ADDRESS:.
```

3. upload the file to FXT or vFXT node:

```bash
scp config_restore.sh VFXT_ADDRESS:/tmp/.
```

4. ssh to the FXT or vFXT node and execute the following command:
```bash
mv /tmp/config_restore.sh /support/Backups/.
```

5. once backup has run, zip up the directory:
```bash
tar zcvf backup.tgz /support/Backups/cluster_rebuild_2020-05-04_17_30_00
cp backup.tgz /tmp
```

6. from the controller or other linux machine download the backup file:
```bash
scp VFXT_ADDRESS:/tmp/backup.tgz .
```

7. Now you can build the terraform files `hpccache-main.tf` and `vfxt-main.tf` to build HPC Cache and Avere vFXT clusters respectively:
```bash
mkdir -p ~/avere-restore
mv backup.tgz ~/avere-restore
cd ~/avere-restore
tar zxvf backup.tgz
wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.8.3/terraform-provider-avere
chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
~/.terraform.d/plugins/terraform-provider-avere cluster_rebuild_2020-05-04_17_30_00
```

8. You can now use the resulting terraform files `hpccache-main.tf` and `vfxt-main.tf` to deploy the clusters.  To learn how to deploy HPC Cache or vFXT clusters see the [Avere Terraform examples page](https://github.com/Azure/Avere/tree/master/src/terraform).
