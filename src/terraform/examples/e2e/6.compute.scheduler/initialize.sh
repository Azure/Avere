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

if [ ${autoScale.enabled} == true ]; then
  systemctl --now enable scale.timer
fi

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

if [ ${cycleCloud.enabled} == true ]; then
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
  echo "IconUrl = https://azrender.blob.core.windows.net/bin/icon.png?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D" >> $clusterTemplateFile
  echo "FormLayout = SelectionPanel" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[node defaults]]" >> $clusterTemplateFile
  echo 'KeyPairLocation = ~/.ssh/cyclecloud.pem' >> $clusterTemplateFile
  echo 'Credentials = $credentials' >> $clusterTemplateFile
  echo 'Region = $regionName' >> $clusterTemplateFile
  echo 'SubnetId = $subnetId' >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[nodearray Render Farm]]" >> $clusterTemplateFile
  echo 'ImageName = $imageId' >> $clusterTemplateFile
  echo 'InitialCount = $initialNodeCount' >> $clusterTemplateFile
  echo 'MachineType = $machineType' >> $clusterTemplateFile
  echo 'Interruptible = $useSpotVM' >> $clusterTemplateFile
  echo 'EphemeralOSDisk = $useEphemeralOSDisk' >> $clusterTemplateFile
  echo 'ComputerNamePrefix = $machineNamePrefix' >> $clusterTemplateFile
  echo 'Azure.MaxScaleSetSize = $maxScaleSetSize' >> $clusterTemplateFile
  echo 'EnableTerminateNotification = true' >> $clusterTemplateFile
  echo "CloudInit = '''#!/bin/bash -ex" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "mkdir -p /mnt/scheduler" >> $clusterTemplateFile
  echo "mkdir -p /mnt/show/write" >> $clusterTemplateFile
  echo "mkdir -p /mnt/show/read" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "echo 'scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0' >> /etc/fstab" >> $clusterTemplateFile
  echo "echo 'azrender1.blob.core.windows.net:/azrender1/show /mnt/show/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0' >> /etc/fstab" >> $clusterTemplateFile
  echo "echo 'cache.artist.studio:/mnt/show /mnt/show/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0' >> /etc/fstab" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "mount -a" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "chmod 777 /mnt/show/write" >> $clusterTemplateFile
  echo "'''" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[configuration]]]" >> $clusterTemplateFile
  echo "cyclecloud.monitor_scheduled_events = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[parameters Required]" >> $clusterTemplateFile
  echo "Order = 1" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Virtual Network]]" >> $clusterTemplateFile
  echo "Order = 10" >> $clusterTemplateFile
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
  echo "Order = 11" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter imageId]]]" >> $clusterTemplateFile
  echo "Label = Node Image" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.Dropdown" >> $clusterTemplateFile
  echo "Config.Entries := $imageList" >> $clusterTemplateFile
  echo "DefaultValue = ${imageIdFarm}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter initialNodeCount]]]" >> $clusterTemplateFile
  echo "Label = Node Count" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.NumberTextBox" >> $clusterTemplateFile
  echo "Config.IntegerOnly = true" >> $clusterTemplateFile
  echo "DefaultValue = 10" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter machineType]]]" >> $clusterTemplateFile
  echo "Label = Node Type" >> $clusterTemplateFile
  echo "ParameterType = Cloud.MachineType" >> $clusterTemplateFile
  echo "DefaultValue = Standard_HB120rs_v2" >> $clusterTemplateFile
  echo "Config.Multiselect = true" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter useSpotVM]]]" >> $clusterTemplateFile
  echo "Label = " >> $clusterTemplateFile
  echo "Widget.Label = Use Spot VM Capacity" >> $clusterTemplateFile
  echo "Widget.Plugin = pico.form.BooleanCheckBox" >> $clusterTemplateFile
  echo "DefaultValue = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter useEphemeralOSDisk]]]" >> $clusterTemplateFile
  echo "Label = " >> $clusterTemplateFile
  echo "Widget.Label = Use Ephemeral OS Disk" >> $clusterTemplateFile
  echo "Widget.Plugin = pico.form.BooleanCheckBox" >> $clusterTemplateFile
  echo "DefaultValue = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[parameters Advanced]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Nodes]]" >> $clusterTemplateFile
  echo "Order = 20" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter machineNamePrefix]]]" >> $clusterTemplateFile
  echo "Label = Machine Name Prefix" >> $clusterTemplateFile
  echo "ParameterType = String" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter maxScaleSetSize]]]" >> $clusterTemplateFile
  echo "Label = Max Scale Set Size" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.NumberTextBox" >> $clusterTemplateFile
  echo "Config.IntegerOnly = true" >> $clusterTemplateFile
  echo "Config.MaxValue = 1000" >> $clusterTemplateFile
  echo "DefaultValue = 40" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Security]]" >> $clusterTemplateFile
  echo "Order = 21" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter credentials]]]" >> $clusterTemplateFile
  echo "Label = Credentials" >> $clusterTemplateFile
  echo "ParameterType = Cloud.Credentials" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  cyclecloud initialize --url=https://localhost:8443 --username=cc_admin --password="${adminPassword}" --batch --verify-ssl=false
  cyclecloud account create -f $cycleAccountFile
  cyclecloud import_template -f $clusterTemplateFile

  versionInfo="3.9.13"
  installFile="Python-$versionInfo.tgz"
  downloadUrl="https://www.python.org/ftp/python/$versionInfo/$installFile"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  yum -y install zlib-devel
  yum -y install libffi-devel
  yum -y install openssl-devel
  cd Python*
  ./configure --enable-optimizations
  make altinstall
  cd ..

  installFile="scaleLib.tar.gz"
  downloadUrl="https://github.com/Azure/cyclecloud-scalelib/archive/refs/tags/0.2.7.tar.gz"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  pip3 install ./tools/cyclecloud_api*.whl
  cd cyclecloud-scalelib*
  /usr/local/bin/python3.9 -m pip install -r dev-requirements.txt
  /usr/local/bin/python3.9 setup.py build
fi
