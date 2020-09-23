# Experimental: Reducing Latency for Cloud Workstations Connected to On-premises NFS Filers

After deploying remote cloud workstations, workstation users can see slow response when creating, deleting, or listing files on remote SMB or NFS shares. This delay is caused by the high latency between the workstations and the on-premises filers.  This guide shows how to use Avere vFXT for Azure to reduce latency to for cloud workstations connected to an on-premises NFS filer.  

The following diagram shows where the Avere vFXT edge cache fits within the cloud workstation architecture:

| Cloud Workstations Without Avere | Cloud Workstations With Avere |
| --- | --- |
| <img src="withoutavere.png"> | <img src="withavere.png"> |

These configurations use customized caching policies to reduce latency. Cache policies control which items are cached and how frequently they are written to and compared with the versions on the back-end filer. [Learn more about cache policies](<https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_manage_cache_policies.html>)

**Important Note:** The cloud workstation feature is experimental. Avere vFXT performs best with read-heavy workloads, but the two cache policies outlined here should improve the artist or user experience over a system that does not use the Avere vFXT edge cache.

To enable CIFS (SMB), please see our [CIFS (SMB) documentation](../../../providers/terraform-provider-avere#cifs_ad_domain) and [example](../../houdinienvironment#phase-2-scaling-step-3b---cache).

## "Isolated Cloud Workstation" Cache Policy

The first and most performant cache policy to consider is named "Isolated Cloud Workstation".  This cache policy can be used when users are isolated and not collaborating on the same workload.  

The following image shows a concrete example where artists are independently working on scenes.  They may have shared read access to a tools directory, and this also works for the isolated cache policy. This example is a candidate for using the "Isolated Cloud Workstation" cache policy.

<div style="text-align:center"><img src="isolatedcloudworkstation.png"></div>

The Isolated Cloud Workstation policy is not designed for situations where multiple users are writing changes to the same file. Cached content can diverge significantly from the on-premises file. [Read more about filer verification settings](<https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_manage_cache_policies.html#cache-policy-settings-advanced-options>)

## "Collaborating Cloud Workstation" Cache Policy

The second cache policy is named "Collaborating Cloud Workstation".  This policy is used when multiple users are collaborating on the same workload.

The following image shows a concrete example where artists are working together on the same scene.  There may also be an artist on premises who is working on the same workload.  This example is a candidate for using the "Collaborating Cloud Workstation" cache policy.

<div style="text-align:center"><img src="collaboratingcloudworkstation.png"></div>

This cache policy includes more frequent checks to compare files in the cache with the versions on the on-premises filer. [Read more about filer verification settings](<https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_manage_cache_policies.html#cache-policy-settings-advanced-options>)

## Deployment Instructions for Avere vFXT

This examples configures a render network, controller, and vFXT with one filer as shown in the diagram below, and lets you choose between Isolated or Shared workstation cache policies:

![The architecture](../../../../../docs/images/terraform/1filer.png)

To run the example, execute the following instructions.  These instructions assume use of Azure Cloud Shell, but you can use your own environment if you install the vFXT provider as described in the [build provider instructions](../../../providers/terraform-provider-avere#build-the-terraform-provider-binary).  However, if you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure). <!-- so you need to do two things if using your own environment? should rephrase -->

1. Browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. Double check your Avere vFXT prerequisites, including running `az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

4. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
```bash
mkdir -p ~/.terraform.d/plugins
# install the vFXT released binary from https://github.com/Azure/Avere
wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.9.17/terraform-provider-avere
chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
```

5. Get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

6. Determine your workstation usage and which cache policy you can use as discussed in [reducing latency for cloud workstations](README.md):
    * If using isolated cloud workstations: `cd src/terraform/examples/vfxt/cloudworkstation/isolatedcloudworkstation`
    * If using collaborating cloud workstations: `cd src/terraform/examples/vfxt/cloudworkstation/collaboratingcloudworkstation`

7. Open `code main.tf` and edit the local variables section at the top of the file to customize to your preferences.  If you are using an [ssk key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys), ensure that ~/.ssh/id_rsa is populated.

8. Execute `terraform init` in the directory of `main.tf`.

9. Execute `terraform apply -auto-approve` to build the vFXT cluster

Once installed you will be able to log in and use the vFXT cluster according to the vFXT documentation: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-cluster-gui.

Try to scale up and down the cluster, adjust the customer settings, add new junctions, etc, by editing the `main.tf`, and running `terraform apply -auto-approve`.

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the three resource groups created.
