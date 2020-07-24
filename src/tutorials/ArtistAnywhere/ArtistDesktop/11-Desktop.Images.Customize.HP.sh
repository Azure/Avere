#!/bin/bash

set -ex

cd /usr/local/bin

fileName=z-central-remote-boost.tar.gz
fileUrl=https://mediasolutions.blob.core.windows.net/bin/ZCentral_RB_2020.0_Lnx_Sender_Receiver_M08153-001.tar.gz
curl -L -o $fileName $fileUrl
