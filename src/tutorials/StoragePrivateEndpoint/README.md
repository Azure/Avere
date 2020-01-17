# Storage Private Endpoint - practical example

When data is critical to the business a common scenario is the ability to lock down a VNET so that data cannot egress from the VNET.

The first approach to partially solve this requirement is to lock down the internet on the NSG, and then lock an azure storage account using a service endpoint, and then  use a service tagtag to lock traffic to storage accounts only within the same geo region.  The details  to  "https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoint-policies-overview.  There is still an attack vector where data could be uploaded to another storage account within the same region.

The second approach is to use private endpoints using the approach described here: https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints.  Combined with a locked down NSG this will full lock down egress to any other storage accounts.  This document provides a simple experiment to setup a storage account with a private endpoint so that you can observe it.

Here are the steps to explore a private storage account.  The steps will create two vnets, where one VNET represents your onprem VNET, and the second VNET represents the locked down cloud VNET.  It installs a linux VM in both VNETs.

1. Create a VM with a new VNET, and a public IP address.  This will act as a jumpbox and your onprem VNET.

2. Create a VNET named "cloudVNET"

3. Create a network security group named "cloud-nsg"

4. Peer the cloud vnet with your onprem VNET created in step 1.

5. Create a VM in the cloud VNET without a public IP and without boot diagnostics (so a storage account isn't created)

6. SSH to onprem VM created in step 1 to use a jumpbox, then SSH to the cloud VM.

7. On the cloud VM install the random blob uploader:

```bash
wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
tar xvf go1.13.5.linux-amd64.tar.gz
sudo chown -R root:root ./go
sudo mv go /usr/local
mkdir ~/gopath
echo "export GOPATH=$HOME/gopath" >> ~/.profile
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
source ~/.profile
rm go1.13.5.linux-amd64.tar.gz
# checkout Checkpoint simulator code, all dependencies and build the binaries
cd $GOPATH
go get -v github.com/Azure/Avere/src/go/...
```

8. create a regular blob account and confirm you can upload to it:

```bash
export AZURE_STORAGE_ACCOUNT="replace with your storage account"
export AZURE_STORAGE_ACCOUNT_KEY="replace with storage account key"
$GOPATH/bin/blobuploader
```

9. Use the NSG and add VNET to VNET traffic, but lockdown all traffic but vnet.  Re-run above to confirm no access.

10. Use portal to create another storage account on the cloud VNET using the private endpoint.

11. Use portal to browse to the new storage account to get its key.  Verify you cannot access the storage account by running the following command:

```bash
export AZURE_STORAGE_ACCOUNT="replace with your private storage account name"
export AZURE_STORAGE_ACCOUNT_KEY="replace with storage account key"
$GOPATH/bin/blobuploader
```

12. Use portal to browse to the private storage account, and browse to "Private endpoint connection" and get its IP address/

13. edit `/etc/hosts` and add the following line


```bash
10.2.1.5 YOUR_PRIVATE_STORAGE_ACCOUNT.blob.core.windows.net
```

14. Now confirm you can upload the blobs:

```bash
export AZURE_STORAGE_ACCOUNT="replace with your private storage account name"
export AZURE_STORAGE_ACCOUNT_KEY="replace with storage account key"
$GOPATH/bin/blobuploader
```

Longer term you will add the CNAME and A record per the article outlined in the second example using the VNET private endpoint: https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints#dns-changes-for-private-endpoints.