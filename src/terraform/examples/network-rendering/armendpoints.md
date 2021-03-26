# ARM Endpoints

If your organization is using a firewall, and you are trying to use Azure Resource Manager endpoint, you may need to pre-populate it with all the endpoints used by `management.azure.com`.  Here is the technique to get the populated list of ARM endpoints:

1. open https://shell.azure.com

2. edit a file `~/findarmendpoints.sh` and add the following contents:
```bash
#!/bin/bash

az account list-locations | jq -r '.[].name' | \
while read i
do
    host $i.management.azure.com | \
    while read i
    do
        if echo $i | grep --quiet " is an alias for "; then
            echo $i | cut -d' ' -f1
        fi
        if echo $i | grep --quiet " has address "; then
            echo $i | cut -d' ' -f1
        fi
    done
done
```

3. mark the file as execute: `chmod +x ~/findarmendpoints.sh`

4. execute `~/findarmurls.sh | sort | uniq`, and you should get a list similar to the following:
```bash
australiacentral2.management.azure.com
australiacentral.management.azure.com
australiaeast.management.azure.com
australiasoutheast.management.azure.com
brazilsoutheast.management.azure.com
brazilsouth.management.azure.com
canadacentral.management.azure.com
canadaeast.management.azure.com
centralindia.management.azure.com
centraluseuap.management.azure.com
centralus.management.azure.com
eastasia.management.azure.com
eastus2euap.management.azure.com
eastus2.management.azure.com
eastus.management.azure.com
francecentral.management.azure.com
francesouth.management.azure.com
germanynorth.management.azure.com
germanywestcentral.management.azure.com
japaneast.management.azure.com
japanwest.management.azure.com
jioindiawest.management.azure.com
koreacentral.management.azure.com
koreasouth.management.azure.com
northcentralus.management.azure.com
northeurope.management.azure.com
norwayeast.management.azure.com
norwaywest.management.azure.com
rpfd-brazilsoutheast.cloudapp.net
rpfd-eastasia.cloudapp.net
rpfd-germanynorth.cloudapp.net
rpfd-germanywestcentral.cloudapp.net
rpfd-jioindiawest.cloudapp.net
rpfd-norwayeast.cloudapp.net
rpfd-norwaywest.cloudapp.net
rpfd-prod-am-01.cloudapp.net
rpfd-prod-bl-01.cloudapp.net
rpfd-prod-bm-01.cloudapp.net
rpfd-prod-bn-01.cloudapp.net
rpfd-prod-bn-euap-01.cloudapp.net
rpfd-prod-by-01.cloudapp.net
rpfd-prod-cb-01.cloudapp.net
rpfd-prod-cb-02.cloudapp.net
rpfd-prod-ch-01.cloudapp.net
rpfd-prod-cq-01.cloudapp.net
rpfd-prod-cw-01.cloudapp.net
rpfd-prod-cy-01.cloudapp.net
rpfd-prod-db-01.cloudapp.net
rpfd-prod-dm-01.cloudapp.net
rpfd-prod-dm-euap-01.cloudapp.net
rpfd-prod-kw-01.cloudapp.net
rpfd-prod-ln-01.cloudapp.net
rpfd-prod-ma-01.cloudapp.net
rpfd-prod-ml-01.cloudapp.net
rpfd-prod-mr-01.cloudapp.net
rpfd-prod-mwh-01.cloudapp.net
rpfd-prod-os-01.cloudapp.net
rpfd-prod-pa-01.cloudapp.net
rpfd-prod-pn-01.cloudapp.net
rpfd-prod-ps-01.cloudapp.net
rpfd-prod-se-01.cloudapp.net
rpfd-prod-sg-01.cloudapp.net
rpfd-prod-sn-01.cloudapp.net
rpfd-prod-sy-01.cloudapp.net
rpfd-prod-yq-01.cloudapp.net
rpfd-prod-yt-01.cloudapp.net
rpfd-southafricanorth.cloudapp.net
rpfd-southafricawest.cloudapp.net
rpfd-switzerlandnorth.cloudapp.net
rpfd-switzerlandwest.cloudapp.net
rpfd-uaecentral.cloudapp.net
rpfd-uaenorth.cloudapp.net
rpfd-westus3.cloudapp.net
southafricanorth.management.azure.com
southafricawest.management.azure.com
southcentralus.management.azure.com
southeastasia.management.azure.com
southindia.management.azure.com
switzerlandnorth.management.azure.com
switzerlandwest.management.azure.com
uaecentral.management.azure.com
uaenorth.management.azure.com
uksouth.management.azure.com
ukwest.management.azure.com
westcentralus.management.azure.com
westeurope.management.azure.com
westindia.management.azure.com
westus2.management.azure.com
westus3.management.azure.com
westus.management.azure.com
```