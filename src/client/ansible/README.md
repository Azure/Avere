# Deploying VMSS and Custom Script Extension (CSE) with Ansible

This folder contains an example template and ansible file that deploys VMSS with Custom Script Extension (CSE).  The following techniques are demonstrated:
1. Update the host name of each VMSS node
1. Run the CSE in a secure firewalled environment
1. Convert the template to Ansible

A custom script extension is chosen over cloud-init for the following reasons:
1. Some OS's like CentOS6 do not support cloud-init
1. Cloud-init is non-blocking and unable to report success or failure like CSE
1. secure strings cannot be delivered through cloud-init.  They can be delivered through CSE when you change "settings" property to "protectedSettings".

You must have created a VNET before running either example.

## Update the host name of each VMSS node

This follows the cloud-init 'hostname' technique described in the [cloud-init code](https://git.launchpad.net/cloud-init/tree/cloudinit/sources/DataSourceAzure.py#n308) and is accomplished through the following two commands:

```
hostname $(GetHostName)
# bounce the interface by using ifdown/ifup
/etc/init.d/network restart
```

## Run the CSE in a secure firewalled environment

Some environments are locked down and do not allow reaching out to the internet to get script files.  This technique gzips and base64's the output and delivers that in the CSE.  The 'script' property is not chosen because we want to pass the parameters.

After you write your script, see `configure_host.sh` for the example, you pack it in the following way:

```
cat hn.sh | sed "s/\r//g" | gzip -c - | base64 -w 0
```

The resulting line from the above command can be used in the property of the `gzipBase64Script` variable of both the ARM template and the ansible script.  From there we execute a command like the following to run the script (in the `commandToExecute` property), setting the environment variables to the necessary values where `H4s...gAA` represents the gzipped base64 encoded script:

```
echo H4s...gAA | base64 --decode | gunzip | HOST_NAME_PREFIX="myvm" NFS_HOST="myvm.mycompany.com" NFS_EXPORT="/someexport" LOCAL_MOUNTPOINT="/nfs/filer" /bin/bash
```

## Convert the template to VMSS

For ansible, the combination of `azure_rm_virtualmachinescaleset` and `azure_rm_virtualmachinescalesetextension` does not work for VMSS for the following reasons:
1. the VMSS is outdated and does not support the latest features such as low priority nodes or placement groups
1. the extension should be bundled with the VMSS, otherwise it never fires

An example of the vmss code is still available under `does_not_work/` folder for those interested in looking at the implementation.

To use VMSS with the latest features you must use the `azure_rm_resource` and the `azure_rm_resource_facts` as shown in our example `vmss.yaml`.  Here is how to execute this from the command line:
1. open https://shell.azure.com
1. export your subscription running the following command `export AZURE_SUBSCRIPTION_ID=YOUR_SUBSCRIPTION_GUID`
1. add the file `vmss.yaml` and update with your values.
1. run `ansible-playbook vmss.yaml` to deploy the VMSS.



