# Checkpoint Simulator

Use the checkpoint simulator to test the speed of a POSIX FileSystem for checkpointing.

## Installation Instructions for Linux

These instructions work on Centos 7 and Ubuntu 18.04. Here are the general steps:
 1. Build the Golang binary
 1. Install the binary and service files to an NFS share
 1. Run the checkpoint simulator against the desired POSIX filesystem path

### Build the checkpointsim binary

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

1. If not already installed go, install golang:

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
    ```

2. setup Checkpoint Simulator code
    ```bash
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/go/...
    ```

Now the checkpoint simulator is created follow the instructions in the test section to test your target POSIX filesystem.

## Testing various POSIX file system performance

This section lists the setup to test the various POSIX file system performance.

As you run these tests it is important to ensure there is enough provisioned memory, bandwidth, and disk space for the size of checkpoint you are creating.  For example, we chose a DS14_v2 for this purpose.

### Ephemeral disk

Deploy a DS14_v2, and run the following command:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /mnt/tmp2 -trialRuns 1 -debug
```

### HDD, Premium, and Ultra Disk

Deploy one of the following disk types:
* **Standard Disk** - a DS14_v2 with a standard disk of size 8192 GiB
* **Premium Disk** - a DS14_v2 with a premium disk of size 8192 GiB
* **Ultra Disk** - an M128 with an ultra disk of at least 2000 Gbps.  An M128 has enough throughput for the ultra disk.

Next run the following instructions to format and mount.

1. Open root shell to make it easy to run below commands

```bash
sudo -s
``` 

2. find the attached disk using `ls -1 /dev/sd*` and set the following env vars, it will be the one with no numbered suffix (eg /dev/sda has devices with suffixes /dev/sda1, /dev/sda14, /dev/sda15)

```bash
DISK="/dev/sdc"
FIRST_PART="${DISK}1"
```

3. Now run the following commands to partition the disk and add to fstab:

```bash
# partition the disk
echo "n
p
1


t
83
w" | fdisk $DISK

# add the ext4 filesystem
mkfs -j -t ext4 $FIRST_PART

# setup the mountpoint
MOUNTPOINT="/disk"
mkdir $MOUNTPOINT
chown nobody:nogroup $MOUNTPOINT
chmod 777 $MOUNTPOINT

read UUID FS_TYPE < <(blkid -u filesystem $FIRST_PART|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
echo -e "UUID=\"${UUID}\"\t$MOUNTPOINT\t$FS_TYPE\tnoatime,nodiratime,nodev,noexec,nosuid,nofail\t1 2" >> /etc/fstab
mount $MOUNTPOINT
```

4. The disk will be mounted, and you can use it.  To finish exit the root shell:
```
exit
````

Now test using the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /disk/tmp -trialRuns 10 -debug
```

### Avere

Install the Avere vFXT from the Marketplace or HPC cache and back it with a blob storage account.  Mount the Avere, and then run the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /nfs/node0/tmp -trialRuns 10 -debug
```

### Azure Files

Create and mount an azure file share according to the instructions: https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-linux.  Next run the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /disk/tmp -trialRuns 10 -debug
```

### Azure Netapp Files

Create and mount an Azure Netapp file share per the instructions: https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-quickstart-set-up-account-create-volumes?tabs=azure-portal.  Next run the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /disk/tmp -trialRuns 10 -debug
```

### Dysk

This uses the Dysk block device to mount a page blob and use it as a filesystem.

1. Create a storage account, lock to VNET, and open HTTP access, as Dysk requires HTTP access

2. Deploy an Ubuntu 16.04 machine (Ubuntu 18.04 with kernel 5 is not supported by Dysk).

3. Run the installation instructions as described here: https://github.com/khenidak/dysk

4. create mount point:

```bash
# setup the mountpoint
MOUNTPOINT="/disk"
sudo mkdir $MOUNTPOINT
sudo chown nobody:nogroup $MOUNTPOINT
sudo chmod 777 $MOUNTPOINT
```

5. Create, format, and mount to /disk a 60 GB page blob as described here (use HTTP, otherwise the machine CPU will hit 100%):  https://github.com/khenidak/dysk/tree/master/examples/101-mount-create

6. Now test using the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /disk/tmp -trialRuns 10 -debug
```

### LSv2 Single Disk

Deploy any LSv2 machine, and run the following commands to configure to configure an NVME disk.

1. Open root shell to make it easy to run below commands

```bash
sudo -s
``` 

2. find the attached disk using `ls -1 /dev/nvme*` and set the following env vars, it will have a single numbered suffix (eg /dev/nvme0n1)

```bash
DISK="/dev/nvme0n1"
FIRST_PART="${DISK}p1"
```

3. Now run the following commands to partition the disk and add to fstab:

```bash
# partition the disk
echo "n
p
1


t
83
w" | fdisk $DISK

# add the ext4 filesystem
mkfs -j -t ext4 $FIRST_PART

# setup the mountpoint
MOUNTPOINT="/disk"
mkdir $MOUNTPOINT
chown nobody:nogroup $MOUNTPOINT
chmod 777 $MOUNTPOINT

read UUID FS_TYPE < <(blkid -u filesystem $FIRST_PART|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
echo -e "UUID=\"${UUID}\"\t$MOUNTPOINT\t$FS_TYPE\tnoatime,nodiratime,nodev,noexec,nosuid,nofail\t1 2" >> /etc/fstab
mount $MOUNTPOINT
```

4. The disk will be mounted, and you can use it.  To finish exit the root shell:
```
exit
````

Now test using the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /disk/tmp -trialRuns 10 -debug
```

### LSv2 Single Raid0

Deploy any L32s_v2 machine, and run the following commands to configure to configure all 4 NVME disks as a single RAID0 disk:

1. Open root shell to make it easy to run below commands

```bash
sudo -s
``` 

2. Now run the following commands to add the nvme disks to raid0 and partition the disk and add to fstab:

```bash
RAIDDISK=/dev/md2
RAIDCHUNKSIZE=2048
DISKCOUNT=4
udevadm control --stop-exec-queue
echo "yes" | mdadm --create $RAIDDISK --name=data --level=0 --chunk=$RAIDCHUNKSIZE --raid-devices=$DISKCOUNT /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
udevadm control --start-exec-queue
mdadm --detail --verbose --scan > /etc/mdadm/mdadm.conf
mdadm --detail --verbose --scan 

# partition the disk
echo "n
p
1


t
83
w" | fdisk $RAIDDISK

FIRST_PART="${RAIDDISK}p1"

# add the ext4 filesystem
mkfs -j -t ext4 $FIRST_PART

# setup the mountpoint
MOUNTPOINT="/disk"
mkdir $MOUNTPOINT
chown nobody:nogroup $MOUNTPOINT
chmod 777 $MOUNTPOINT

read UUID FS_TYPE < <(blkid -u filesystem $FIRST_PART|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
echo -e "UUID=\"${UUID}\"\t$MOUNTPOINT\t$FS_TYPE\tnoatime,nodiratime,nodev,noexec,nosuid,nofail\t1 2" >> /etc/fstab
mount $MOUNTPOINT
```

3. The disk will be mounted, and you can use it.  To finish exit the root shell:

```bash
exit
````

4. Now test using the checkpoint simulator:

```bash
sudo $GOPATH/bin/checkpointsim -checkpointSizeBytes 64424509440 -targetDirectory /disk/tmp -trialRuns 10 -debug
```