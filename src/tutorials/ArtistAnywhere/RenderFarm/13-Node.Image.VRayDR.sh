#!/bin/bash

set -ex

cd /usr/local/bin

downloadUrl='https://mediasolutions.blob.core.windows.net/bin/ChaosGroup'

fileName='vray_adv_50022_maya2020_centos7'
curl -L -o $fileName $downloadUrl/$fileName

configFileName='vray_config_linux.xml'
curl -L -o $configFileName $downloadUrl/$configFileName

chmod +x $fileName
./$fileName -gui=0 -quite=1 -configFile=$configFileName
