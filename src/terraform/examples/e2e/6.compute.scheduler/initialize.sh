#!/bin/bash -ex

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

customDataInputFile="/var/lib/waagent/ovf-env.xml"
customDataOutputFile="/var/lib/waagent/scale.sh"
customData=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $customDataInputFile)
echo $customData | base64 -d | gzip -d > $customDataOutputFile

scaleServicePath="/etc/systemd/system/scale.service"
echo "[Unit]" > $scaleServicePath
echo "Description=Render Farm Scaler Service" >> $scaleServicePath
echo "" >> $scaleServicePath
echo "[Service]" >> $scaleServicePath
echo "Environment=PATH=$schedulerPath:$PATH" >> $scaleServicePath
echo "Environment=scaleSetName=${autoScale.scaleSetName}" >> $scaleServicePath
echo "Environment=resourceGroupName=${autoScale.resourceGroupName}" >> $scaleServicePath
echo "Environment=jobWaitThresholdSeconds=${autoScale.jobWaitThresholdSeconds}" >> $scaleServicePath
echo "Environment=workerIdleDeleteSeconds=${autoScale.workerIdleDeleteSeconds}" >> $scaleServicePath
echo "ExecStart=/bin/bash $customDataOutputFile" >> $scaleServicePath
echo "" >> $scaleServicePath
scaleTimerPath="/etc/systemd/system/scale.timer"
echo "[Unit]" > $scaleTimerPath
echo "Description=Render Farm Scaler Timer" >> $scaleTimerPath
echo "" >> $scaleTimerPath
echo "[Timer]" >> $scaleTimerPath
echo "OnBootSec=10" >> $scaleTimerPath
echo "OnUnitActiveSec=${autoScale.detectionIntervalSeconds}" >> $scaleTimerPath
echo "AccuracySec=1us" >> $scaleTimerPath
echo "" >> $scaleTimerPath
echo "[Install]" >> $scaleTimerPath
echo "WantedBy=timers.target" >> $scaleTimerPath

if [ ${autoScale.enable} == true ]; then
  systemctl --now enable scale.timer
fi

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

if [ ${cycleCloud.enable} == true ]; then
  az login --identity
  imageList="{"
  imageDefinitions=$(az sig image-definition list --resource-group ${imageResourceGroupName} --gallery-name ${imageGalleryName})
  for imageDefinition in $(echo $imageDefinitions | jq -c .[]); do
    imageDefinitionName=$(echo $imageDefinition | jq -r .name)
    imageVersions=$(az sig image-version list --resource-group ${imageResourceGroupName} --gallery-name ${imageGalleryName} --gallery-image-definition $imageDefinitionName)
    for imageVersion in $(echo $imageVersions | jq -r '.[] | @base64'); do
      _jq() {
        echo $imageVersion | base64 -d | jq -r $1
      }
      imageVersionId=$(_jq .id)
      imageVersionName=$(_jq .name)
      if [ "$imageList" != "{" ]; then
        imageList="$imageList,"
      fi
      imageList="$imageList[Label=\"$imageDefinitionName v$imageVersionName\";Value=\"$imageVersionId\"]"
    done
  done
  imageList="$imageList}"
  cd /opt/cycle_server
  cycleAccountFile="cycle_account.json"
  echo "{" > $cycleAccountFile
  echo "\"Name\": \"Azure\"," >> $cycleAccountFile
  echo "\"Location\": \"${regionName}\"," >> $cycleAccountFile
  echo "\"Provider\": \"azure\"," >> $cycleAccountFile
  echo "\"ProviderId\": \"${subscriptionId}\"," >> $cycleAccountFile
  echo "\"Environment\": \"public\"," >> $cycleAccountFile
  echo "\"DefaultAccount\": true," >> $cycleAccountFile
  echo "\"AzureRMTenantId\": \"${tenantId}\"," >> $cycleAccountFile
  echo "\"AzureRMSubscriptionId\": \"${subscriptionId}\"," >> $cycleAccountFile
  echo "\"AzureRMUseManagedIdentity\": true," >> $cycleAccountFile
  echo "\"RMStorageAccount\": \"${cycleCloud.storageAccount.name}\"," >> $cycleAccountFile
  echo "\"RMStorageContainer\": \"cyclecloud\"" >> $cycleAccountFile
  echo "}" >> $cycleAccountFile
  clusterTemplateFile="cluster_template.txt"
  echo "[cluster Render Farm]" > $clusterTemplateFile
  echo "Category = Schedulers" >> $clusterTemplateFile
  echo "IconUrl = https://azartist.blob.core.windows.net/bin/render.png?sv=2020-10-02&st=2022-01-01T00%3A00%3A00Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=4N8gUHTPNOG%2BlgEPvQljsRPCOsRD3ZWfiBKl%2BRxl9S8%3D" >> $clusterTemplateFile
  echo "FormLayout = SelectionPanel" >> $clusterTemplateFile
  echo 'Autoscale = $autoScale' >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[node defaults]]" >> $clusterTemplateFile
  echo 'Credentials = $credentials' >> $clusterTemplateFile
  echo 'Region = $regionName' >> $clusterTemplateFile
  echo 'SubnetId = $subnetId' >> $clusterTemplateFile
  echo 'ImageName = $imageId' >> $clusterTemplateFile
  echo 'MachineType = $machineType' >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[nodearray Render Farm]]" >> $clusterTemplateFile
  echo 'InitialCount = $initialNodeCount' >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[parameters Required]" >> $clusterTemplateFile
  echo "Order = 1" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Virtual Network]]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter regionName]]]" >> $clusterTemplateFile
  echo "Label = Region" >> $clusterTemplateFile
  echo "ParameterType = Cloud.Region" >> $clusterTemplateFile
  echo "DefaultValue = ${regionName}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "Disabled = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter subnetId]]]" >> $clusterTemplateFile
  echo "Label = Subnet" >> $clusterTemplateFile
  echo "ParameterType = Azure.Subnet" >> $clusterTemplateFile
  echo "DefaultValue = ${networkResourceGroupName}/${networkName}/${networkSubnetName}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Virtual Machine]]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter imageId]]]" >> $clusterTemplateFile
  echo "Label = Node Image" >> $clusterTemplateFile
  echo "ParameterType = StringList" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.Dropdown" >> $clusterTemplateFile
  echo "Config.Entries := $imageList" >> $clusterTemplateFile
  echo "DefaultValue = ${imageIdFarm}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter machineType]]]" >> $clusterTemplateFile
  echo "Label = Node Type" >> $clusterTemplateFile
  echo "ParameterType = Cloud.MachineType" >> $clusterTemplateFile
  echo "DefaultValue = Standard_HB120rs_v2" >> $clusterTemplateFile
  echo "Config.Multiselect = true" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter initialNodeCount]]]" >> $clusterTemplateFile
  echo "Label = Node Count" >> $clusterTemplateFile
  echo "DefaultValue = 10" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[parameters Advanced]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Scale]]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter autoScale]]]" >> $clusterTemplateFile
  echo "Label = Auto Scale" >> $clusterTemplateFile
  echo "ParameterType = Boolean" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Security]]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter credentials]]]" >> $clusterTemplateFile
  echo "Label = Credentials" >> $clusterTemplateFile
  echo "ParameterType = Cloud.Credentials" >> $clusterTemplateFile
  cyclecloud initialize --url=http://localhost:8080 --username=cc_admin --password="${adminPassword}" --batch
  cyclecloud account create -f $cycleAccountFile
  cyclecloud import_template -f $clusterTemplateFile
fi
