

#!/bin/bash

set -x

function wait_vfxt_log() {
    mountpoint=$1
    while :
    do

        if timeout 5 ls $mountpoint; then
            echo "mount is live"
            break
        fi
        echo "$(date) mount is frozen"
    done
}

export DstSub="b52fce95-de5f-4b37-afca-db203a5d0b6a"
export DstResourceGroupName="avereeastusbatch"
export DstLocation="eastus"
export BatchAccountName="avereeastusbatch"
az account set --subscription $DstSub
az batch account login --resource-group $DstResourceGroupName --name $BatchAccountName
wait_vfxt_log "/nfs/node0"